#!/usr/bin/env bun
// brainstem doctor — 檢查環境就緒。紅項缺 → exit 1;黃/灰僅提示。
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { findBrain } from "./lib/find-brain.mjs";
import { resolveDrafts, pinnedDraftsDir } from "./lib/drafts.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const BRAIN = findBrain();
const pinnedDrafts = pinnedDraftsDir();
if (!BRAIN) {
  if (pinnedDrafts) console.log(`  ·  drafts: ${pinnedDrafts}(pinned,目前無腦)`);  // 對齊 info() 的 ·  前綴
  process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init/use。\n");
  process.exit(1);
}
let red = 0;
const ok = (m) => console.log(`  ✅ ${m}`);
const fail = (m) => { console.log(`  ❌ ${m}`); red++; };
const warn = (m) => console.log(`  🟡 ${m}`);
const info = (m) => console.log(`  ·  ${m}`);

console.log("== brainstem doctor ==");
console.log(`brain: ${BRAIN}`);

// 必檢(紅)
existsSync(join(BRAIN, ".brainroot")) ? ok(".brainroot 存在") : fail(".brainroot 不存在 — 這裡不是 brain 根");
const lensPath = join(BRAIN, "lens.md");
if (!existsSync(lensPath)) fail("lens.md 不存在");
else if (readFileSync(lensPath, "utf8").includes("LENS_UNCONFIGURED")) fail("lens.md 尚未設定(仍含 LENS_UNCONFIGURED)— 先填 lens");
else ok("lens.md 已設定");

// 資訊
info(`Bun ${Bun.version}`);
const verFile = join(HERE, "VERSION");
info(`brainstem ${existsSync(verFile) ? readFileSync(verFile, "utf8").trim() : "(no VERSION)"}`);
Bun.which("brainstem") ? ok("brainstem 指令在 PATH") : warn("brainstem 不在 PATH — 把 ~/.local/bin 加進 PATH 或重跑 install.sh");
info(`drafts: ${resolveDrafts()}${pinnedDrafts ? "(pinned)" : "(預設,跟腦)"}`);

// recommended(黃)
Bun.which("yt-dlp") ? ok("yt-dlp 可用(YouTube 抓字幕)") : warn("yt-dlp 未裝(YouTube 來源需要)— 裝:brew install yt-dlp 或 pipx install yt-dlp");

// optional(灰)
const appleSilicon = process.platform === "darwin" && process.arch === "arm64";
const whisper = appleSilicon ? "mlx-whisper(Apple Silicon)" : "faster-whisper(CUDA/CPU)";
info(`whisper(只無字幕影片才需要):你的 OS 建議用 ${whisper}`);

console.log(red ? `\n${red} 項必檢未過 ✗` : "\n全部就緒 ✓");
process.exit(red ? 1 : 0);
