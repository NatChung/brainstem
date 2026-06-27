// 讀/寫全域腦指標。set <dir>:正規化絕對路徑、驗 .brainroot、寫 config.json。
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { configPath } from "./find-brain.mjs";

export function setBrain(dir) {
  const abs = resolve(dir);
  if (!existsSync(join(abs, ".brainroot"))) {
    process.stderr.write(`拒絕:${abs} 不含 .brainroot,不是一顆腦。\n`);
    process.exit(1);
  }
  const cp = configPath();
  mkdirSync(dirname(cp), { recursive: true });
  writeFileSync(cp, JSON.stringify({ brain: abs }, null, 2) + "\n");
  process.stdout.write(`已設定預設腦:${abs}\n`);
}

if (import.meta.main) {
  const [cmd, dir] = process.argv.slice(2);
  if (cmd === "set" && dir) setBrain(dir);
  else { process.stderr.write("用法:config.mjs set <dir>\n"); process.exit(1); }
}
