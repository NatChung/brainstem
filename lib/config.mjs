// 讀/寫全域 config(brain 指標 + draftsDir)。所有寫入 read-merge-write,不互相覆蓋。
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { configPath } from "./find-brain.mjs";
import { draftsPinnedNotice } from "./drafts.mjs";

function readConfig() {
  const cp = configPath();
  if (!existsSync(cp)) return {};
  try { return JSON.parse(readFileSync(cp, "utf8")) || {}; } catch { return {}; }
}
function writeConfig(obj) {
  const cp = configPath();
  mkdirSync(dirname(cp), { recursive: true });
  writeFileSync(cp, JSON.stringify(obj, null, 2) + "\n");
}

export function currentBrain() { return readConfig().brain ?? null; }

export function setBrain(dir) {
  const abs = resolve(dir);
  if (!existsSync(join(abs, ".brainroot"))) {
    process.stderr.write(`拒絕:${abs} 不含 .brainroot,不是一顆腦。\n`);
    process.exit(1);
  }
  const c = readConfig(); c.brain = abs; writeConfig(c);
  process.stdout.write(`已設定預設腦:${abs}\n`);
  const n = draftsPinnedNotice();
  if (n) process.stdout.write(n + "\n");
}

export function setDrafts(dir) {
  const abs = resolve(dir);
  mkdirSync(abs, { recursive: true });
  const c = readConfig(); c.draftsDir = abs; writeConfig(c);
  process.stdout.write(`已設定 drafts 落點:${abs}\n`);
}

export function unsetDrafts() {
  const c = readConfig(); delete c.draftsDir; writeConfig(c);
  process.stdout.write("drafts 落點已改回預設($BRAIN/docs/drafts)\n");
}

if (import.meta.main) {
  const [cmd, dir] = process.argv.slice(2);
  if (cmd === "set" && dir) setBrain(dir);
  else if (cmd === "set-drafts" && dir) setDrafts(dir);
  else if (cmd === "unset-drafts") unsetDrafts();
  else { process.stderr.write("用法:config.mjs <set <dir> | set-drafts <dir> | unset-drafts>\n"); process.exit(1); }
}
