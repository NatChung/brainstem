#!/usr/bin/env bun
// brain 體檢 + 去重工具。唯讀,不改圖。
//   bun run brain            → 健康報告(規模/成熟度/來源/主題/圖健康/合規/log 大小)
//   bun run brain --dup <s>  → 去重:<s>(URL / 影片 id / 路徑)餵過沒(掃所有 note/entity 全文)
// 真相源 = note/entity 檔本身;_index.md / log.md 只是人讀的指標,不是這支的依據。
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const BRAIN = dirname(fileURLToPath(import.meta.url));
const rel = p => p.replace(BRAIN + "/", "");
const md = (d) =>
  existsSync(d)
    ? readdirSync(d).filter((f) => f.endsWith(".md")).map((f) => ({
        slug: f.replace(/\.md$/, ""),
        path: join(d, f),
        raw: readFileSync(join(d, f), "utf8"),
      }))
    : [];

const NOTES = md(join(BRAIN, "notes"));
const ENTS = md(join(BRAIN, "entities"));
const ALL = [...NOTES, ...ENTS];

// ---- 去重模式 ----
const args = process.argv.slice(2);
const dupIdx = args.findIndex((a) => a === "--dup" || a === "--source" || a === "dup");
if (dupIdx !== -1) {
  const term = (args[dupIdx + 1] || "").trim();
  if (!term) {
    console.error("用法: bun run brain --dup <url | 影片id | 路徑>");
    process.exit(2);
  }
  const hits = ALL.filter((x) => x.raw.includes(term));
  if (hits.length) {
    console.log(`⚠️  已餵過 —「${term}」出現在 ${hits.length} 個檔:`);
    hits.forEach((h) => console.log(`   ${rel(h.path)}`));
    process.exit(1);
  }
  console.log(`✓ 未餵過 —「${term}」不在任何 note/entity,可安全 ingest`);
  process.exit(0);
}

// ---- 健康模式 ----
const fm = (raw) => (raw.match(/^---\n([\s\S]*?)\n---/) || [, ""])[1];
const field = (f, k) => (f.match(new RegExp(`^${k}:\\s*(.*)$`, "m")) || [, null])[1]?.trim() ?? null;
const arr = (f, k) => {
  const v = field(f, k);
  if (!v) return [];
  return [...v.matchAll(/["[]?([^"\[\],]+)["\]]?/g)].map((x) => x[1].trim()).filter((x) => x && x !== "[" && x !== "]");
};
const wl = (raw) => [...raw.matchAll(/\[\[([^\]]+)\]\]/g)].map((m) => m[1]);

const slugs = new Set(ALL.map((x) => x.slug));
const backlink = {}, outdeg = {}, broken = [];
ALL.forEach((x) => {
  const links = wl(x.raw);
  outdeg[x.slug] = new Set(links).size;
  links.forEach((l) => (slugs.has(l) ? (backlink[l] = (backlink[l] || 0) + 1) : broken.push(`${x.slug} → [[${l}]]`)));
});
const orphans = NOTES.filter((n) => !(outdeg[n.slug] > 0) && !backlink[n.slug]);

const stat = {}, tags = {};
NOTES.forEach((n) => {
  const f = fm(n.raw);
  stat[field(f, "status") || "?"] = (stat[field(f, "status") || "?"] || 0) + 1;
  arr(f, "tags").forEach((t) => (tags[t] = (tags[t] || 0) + 1));
});
const sensitive = ALL.filter((x) => field(fm(x.raw), "sensitive") === "true").length;
const drafts = existsSync(join(BRAIN, "docs/drafts")) ? readdirSync(join(BRAIN, "docs/drafts")).filter((f) => f.endsWith(".md")).length : 0;
const logLines = existsSync(join(BRAIN, "log.md")) ? readFileSync(join(BRAIN, "log.md"), "utf8").split("\n").filter((l) => l.trim()).length : 0;
const top = (o, n) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, n);

console.log(`== 規模 ==\nnotes:${NOTES.length}  entities:${ENTS.length}  drafts:${drafts}`);
console.log(`\n== 成熟度漏斗 ==`);
top(stat, 9).forEach(([k, v]) => console.log(`  ${k}: ${v}`));
console.log(`\n== 主題厚薄 (top tags) ==`);
top(tags, 12).forEach(([k, v]) => console.log(`  ${k}: ${v}`));
console.log(`\n== 圖健康 ==`);
console.log(`  孤島 note: ${orphans.length}${orphans.length ? " → " + orphans.map((o) => o.slug).join(", ") : " ✓"}`);
console.log(`  斷鏈: ${broken.length}${broken.length ? " → " + broken.join("; ") : " ✓"}`);
console.log(`  樞紐 (連入 top5):`);
top(backlink, 5).forEach(([k, v]) => console.log(`    ${k}: ${v}`));
console.log(`\n== 合規 ==\n  sensitive:true 的頁: ${sensitive}`);
console.log(`\n== 維護 ==\n  log.md: ${logLines} 行${logLines > 300 ? "  ⚠️ 超過 300,該 roll 成 log-<年>.md" : " ✓"}`);

if (broken.length) process.exit(1);
