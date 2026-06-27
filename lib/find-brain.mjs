// 解析「腦在哪」:BRAIN_DIR → cwd 上行 .brainroot → 全域指標 → null。
// 直跑 = `brainstem where`:印絕對路徑(stdout)或錯誤(stderr)+ exit 1。
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { homedir } from "node:os";

export function configPath() {
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "brainstem", "config.json");
}

export function findBrain() {
  // 1. BRAIN_DIR — 直接採信,不要求 .brainroot
  if (process.env.BRAIN_DIR) return resolve(process.env.BRAIN_DIR);
  // 2. cwd 往上找第一個含 .brainroot 的目錄
  let d = process.cwd();
  for (;;) {
    if (existsSync(join(d, ".brainroot"))) return d;
    const parent = dirname(d);
    if (parent === d) break;
    d = parent;
  }
  // 3. 全域指標(需仍含 .brainroot,否則視為失效)
  const cp = configPath();
  if (existsSync(cp)) {
    try {
      const { brain } = JSON.parse(readFileSync(cp, "utf8"));
      if (brain && existsSync(join(brain, ".brainroot"))) return brain;
    } catch { /* 壞檔當作沒設 */ }
  }
  return null;
}

if (import.meta.main) {
  const brain = findBrain();
  if (!brain) {
    process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init <dir> / brainstem use <dir>。\n");
    process.exit(1);
  }
  process.stdout.write(brain + "\n");
}
