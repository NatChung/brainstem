// synthesize 草稿落點解析:draftsDir(全域 config,pin)→ 否則 $BRAIN/docs/drafts。
// 直跑 = `brainstem drafts`:印解析結果(stdout)或錯誤(stderr)+ exit 1。
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { findBrain, configPath } from "./find-brain.mjs";

// config 的 draftsDir(pin);未設 / 壞檔 / 無 key → null。採信不驗。
export function pinnedDraftsDir() {
  const cp = configPath();
  if (!existsSync(cp)) return null;
  try {
    const { draftsDir } = JSON.parse(readFileSync(cp, "utf8"));
    return draftsDir || null;
  } catch { return null; }
}

// 落點:pin 優先(免腦);否則 $BRAIN/docs/drafts(無腦則 null)。
export function resolveDrafts() {
  const pinned = pinnedDraftsDir();
  if (pinned) return pinned;
  const brain = findBrain();
  return brain ? join(brain, "docs/drafts") : null;
}

// drafts 被 pin 時的提醒字串;未 pin → null。
export function draftsPinnedNotice() {
  const p = pinnedDraftsDir();
  return p ? `注意:drafts 固定在 ${p},不隨腦切換;brainstem drafts --default 可改回跟著腦` : null;
}

if (import.meta.main) {
  const d = resolveDrafts();
  if (!d) {
    process.stderr.write("找不到草稿落點 — 未設 draftsDir 且找不到腦。cd 進一顆,或 brainstem drafts <dir> / brainstem use <dir>。\n");
    process.exit(1);
  }
  process.stdout.write(d + "\n");
}
