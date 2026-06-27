// brainstem init <dir>:複製 _brain-template/ → <dir>,防呆,首顆設為預設腦。
import { existsSync, mkdirSync, cpSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { setBrain } from "./lib/config.mjs";
import { configPath } from "./lib/find-brain.mjs";

const ENGINE = dirname(fileURLToPath(import.meta.url));
const TEMPLATE = join(ENGINE, "_brain-template");

const arg = process.argv[2];
if (!arg) { process.stderr.write("用法:brainstem init <dir>\n"); process.exit(1); }
const abs = resolve(arg);

if (existsSync(join(abs, ".brainroot"))) {
  process.stderr.write(`拒絕:${abs} 已是一顆腦(含 .brainroot)。\n`); process.exit(1);
}
if (existsSync(abs) && readdirSync(abs).length > 0) {
  process.stderr.write(`拒絕:${abs} 非空且非腦。請換空目錄或先清。\n`); process.exit(1);
}

mkdirSync(abs, { recursive: true });
cpSync(TEMPLATE, abs, { recursive: true });
process.stdout.write(`已建立腦:${abs}\n`);

if (!existsSync(configPath())) setBrain(abs);

process.stdout.write(`下一步:cd ${abs},用 Claude Code 開啟說 hi 走 onboarding。建議 git init + 設私有 remote。\n`);
