# Configurable Drafts Dir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global, optional `draftsDir` so synthesize's draft output can be pinned to any absolute dir; unset = today's `$BRAIN/docs/drafts`.

**Architecture:** A new `lib/drafts.mjs` resolves the drafts dir (`draftsDir` pin → else `$BRAIN/docs/drafts`). `lib/config.mjs` gains read-merge-write helpers so `brain` and `draftsDir` keys coexist (the current `setBrain` overwrites the whole file — must be fixed). The `brainstem` dispatcher gains a `drafts` subcommand; `check.mjs`/`doctor.mjs`/synthesize consume the resolver; `use`/`init` print a one-line notice when drafts are pinned.

**Tech Stack:** Bun (`.mjs` via `bun`, `import.meta.main`, `Bun.which`), POSIX bash. Spec: `docs/superpowers/specs/2026-06-27-drafts-dir-design.md`.

## Global Constraints

- Spec of record: `docs/superpowers/specs/2026-06-27-drafts-dir-design.md` — every task inherits it.
- Config = `${XDG_CONFIG_HOME:-$HOME/.config}/brainstem/config.json`, shape `{ "brain": "<abs>", "draftsDir": "<abs>" }` (either key may be absent).
- **All config writes are read-merge-write** — never overwrite the whole file (it would clobber the other key). Applies to `setBrain`, `setDrafts`, `unsetDrafts`.
- Resolution: `draftsDir` if set (trusted as-is, no validation, works without a brain) → else `join(findBrain(), "docs/drafts")` → null/error if no brain.
- All config/drafts reads use synchronous `readFileSync` and wrap `JSON.parse` in try/catch (corrupt/absent → treated as unset). Matches `lib/find-brain.mjs`.
- Errors → stderr + exit 1; resolved paths / success messages → stdout.
- `brainstem where` stays brain-only (single-value contract); both paths surface via `brainstem doctor`.
- Tests: bash under `bin/`, run `bash bin/<name>.sh`, print `PASS`/`FAIL`, non-zero exit on failure; no framework. Use `pwd -P` to normalize `mktemp` dirs.
- Backward compatible: with `draftsDir` unset, behavior is identical to today. `install.sh` is NOT changed; re-running it upgrades.
- Comments/docs in 中文. Commit messages end with the repo's Co-Authored-By trailer. Branch `design/brain-engine-separation` (already checked out) — do not branch.

## File Structure

| File | Responsibility |
|---|---|
| `lib/drafts.mjs` | NEW. `resolveDrafts()`, `pinnedDraftsDir()`, `draftsPinnedNotice()`; direct-run = `brainstem drafts`. |
| `lib/config.mjs` | Add internal `readConfig`/`writeConfig`; `setBrain` → read-merge-write + pinned notice; add `setDrafts`, `unsetDrafts`, `currentBrain`; CLI gains `set-drafts`/`unset-drafts`. |
| `bin/brainstem` | Add `drafts` dispatch (arity-guarded); multi-line `--help`. |
| `check.mjs` | Drafts count via `resolveDrafts()`. |
| `doctor.mjs` | Show resolved drafts (pinned before the no-brain exit; default after brain resolves). |
| `init.mjs` | Gate brain-pointer-set on the `brain` key (not file presence); pinned notice. |
| `skills/brainstem-synthesize/SKILL.md` | Use `$DRAFTS` everywhere; `mkdir -p` before write. |
| `README.md`, `CLAUDE.md`, `_brain-template/CLAUDE.md` | Add `brainstem drafts` usage. |
| `bin/test-drafts.sh`, `bin/test-config-merge.sh`, `bin/test-drafts-cli.sh`, `bin/test-check-drafts.sh`, `bin/test-drafts-notice.sh` | NEW tests. `bin/test-skills-wiring.sh` extended. |

Order is linear T1→T7; T2 imports from T1, T3 needs T1+T2, T4/T5 need T1(+T2).

---

## Task 1: `lib/drafts.mjs` — resolver + `brainstem drafts` read CLI

**Files:**
- Create: `lib/drafts.mjs`, `bin/test-drafts.sh`

**Interfaces:**
- Consumes: `findBrain()`, `configPath()` from `./find-brain.mjs`.
- Produces: `resolveDrafts(): string｜null`, `pinnedDraftsDir(): string｜null`, `draftsPinnedNotice(): string｜null`. Direct-run prints `resolveDrafts()` to stdout or errors to stderr + exit 1.

- [ ] **Step 1: Write the failing test** — `bin/test-drafts.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DR="$ROOT/lib/drafts.mjs"

# 1. 未設 draftsDir → $BRAIN/docs/drafts(經 BRAIN_DIR)
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"
CFG="$(mktemp -d)"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$B/docs/drafts" ] || { echo "FAIL: unset should follow brain, got '$OUT'"; exit 1; }

# 5a. 設了 draftsDir → 回它,且免腦也成立
D="$(cd "$(mktemp -d)" && pwd -P)/out"
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$D" ] || { echo "FAIL: pinned should win without brain, got '$OUT'"; exit 1; }

# 5b. pinned 蓋過腦
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$D" ] || { echo "FAIL: pinned should override brain, got '$OUT'"; exit 1; }

# 6. 未設且無腦 → stderr + exit 1,stdout 空
EMPTY="$(mktemp -d)"
if OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$EMPTY" bun "$DR" 2>/dev/null)"; then echo "FAIL: no brain+unset should exit 1"; exit 1; fi
[ -z "${OUT:-}" ] || { echo "FAIL: should not print path on error"; exit 1; }

# 壞檔當未設 → 回退到腦
printf 'not json{' > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$B/docs/drafts" ] || { echo "FAIL: corrupt config should be treated as unset, got '$OUT'"; exit 1; }

rm -rf "$B" "$CFG" "$EMPTY" "$(dirname "$D")"
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-drafts.sh`
Expected: FAIL (`lib/drafts.mjs` missing → bun error).

- [ ] **Step 3: Implement `lib/drafts.mjs`**

```js
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
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bash bin/test-drafts.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add lib/drafts.mjs bin/test-drafts.sh
git commit -m "feat: lib/drafts.mjs — 草稿落點解析(draftsDir pin → 跟腦)+ brainstem drafts 讀"
```

---

## Task 2: `lib/config.mjs` — read-merge-write + drafts setters

**Files:**
- Modify: `lib/config.mjs` (full rewrite of the small file)
- Create: `bin/test-config-merge.sh`

**Interfaces:**
- Consumes: `configPath()` from `./find-brain.mjs`; `draftsPinnedNotice()` from `./drafts.mjs` (Task 1).
- Produces: `setBrain(dir)`, `setDrafts(dir)`, `unsetDrafts()`, `currentBrain(): string｜null`. CLI: `set <dir>｜set-drafts <dir>｜unset-drafts`.

- [ ] **Step 1: Write the failing test** — `bin/test-config-merge.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFGJS="$ROOT/lib/config.mjs"
CFG="$(mktemp -d)"; cfgfile="$CFG/brainstem/config.json"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"

# set-drafts:建夾 + 寫 key
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
[ -d "$D" ] || { echo "FAIL: set-drafts should mkdir -p"; exit 1; }
grep -q '"draftsDir"' "$cfgfile" || { echo "FAIL: draftsDir not written"; exit 1; }

# 反序(Critical 回歸):set-drafts 在前,再 set 腦 → 兩個 key 都在
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B" >/dev/null
grep -q '"brain"' "$cfgfile" || { echo "FAIL: brain not written"; exit 1; }
grep -q '"draftsDir"' "$cfgfile" || { echo "FAIL: setBrain clobbered draftsDir"; exit 1; }

# 反向:先 set 腦再 set-drafts → 兩個都在
rm -f "$cfgfile"
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B" >/dev/null
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
{ grep -q '"brain"' "$cfgfile" && grep -q '"draftsDir"' "$cfgfile"; } || { echo "FAIL: set-drafts clobbered brain"; exit 1; }

# unset-drafts:draftsDir 消失、brain 保留
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" unset-drafts >/dev/null
grep -q '"draftsDir"' "$cfgfile" && { echo "FAIL: draftsDir not removed"; exit 1; }
grep -q '"brain"' "$cfgfile" || { echo "FAIL: unset-drafts clobbered brain"; exit 1; }

# setBrain pinned 提醒
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
OUT="$(XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B")"
echo "$OUT" | grep -q "不隨腦切換" || { echo "FAIL: setBrain should warn when drafts pinned"; exit 1; }

rm -rf "$CFG" "$B" "$(dirname "$D")"
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-config-merge.sh`
Expected: FAIL (`set-drafts` unknown / `setBrain` overwrites → draftsDir clobbered).

- [ ] **Step 3: Rewrite `lib/config.mjs`**

```js
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
```

- [ ] **Step 4: Run new test + the existing config/init regressions**

Run: `bash bin/test-config-merge.sh && bash bin/test-config.sh && bash bin/test-init.sh`
Expected: all three `PASS` (existing `setBrain`/`set` path unchanged in behavior; init still scaffolds + sets first brain).

- [ ] **Step 5: Commit**

```bash
git add lib/config.mjs bin/test-config-merge.sh
git commit -m "feat: config.mjs read-merge-write + set-drafts/unset-drafts/currentBrain"
```

---

## Task 3: `bin/brainstem` — `drafts` dispatch + multi-line `--help`

**Files:**
- Modify: `bin/brainstem`
- Create: `bin/test-drafts-cli.sh`

**Interfaces:**
- Consumes: `lib/drafts.mjs` (Task 1), `lib/config.mjs set-drafts/unset-drafts` (Task 2).
- Produces: `brainstem drafts [<dir> | --default]` end-to-end.

- [ ] **Step 1: Write the failing test** — `bin/test-drafts-cli.sh`

```bash
#!/usr/bin/env bash
# 臨時安裝後端到端驗 drafts 子命令(同 test-install.sh 模式)。
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/home/.local/share" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/home/.local/bin:$PATH"
mkdir -p "$HOME"
bash "$SRC/install.sh" >/dev/null

D="$TMP/blog/content"
brainstem drafts "$D" >/dev/null            # set
[ -d "$D" ] || { echo "FAIL: drafts <dir> should mkdir"; exit 1; }
OUT="$(brainstem drafts)"                    # get(免腦,pinned)
[ "$OUT" = "$D" ] || { echo "FAIL: drafts get got '$OUT'"; exit 1; }
if brainstem drafts a b >/dev/null 2>&1; then echo "FAIL: extra args should error"; exit 1; fi

brainstem init "$TMP/brain" >/dev/null       # 開一顆腦(draftsDir 已設→init 仍設 brain key)
brainstem drafts --default >/dev/null        # 清回跟腦
OUT="$(brainstem drafts)"
[ "$OUT" = "$TMP/brain/docs/drafts" ] || { echo "FAIL: after --default should follow brain, got '$OUT'"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-drafts-cli.sh`
Expected: FAIL (`unknown subcommand: drafts`).

- [ ] **Step 3: Edit `bin/brainstem`** — add `drafts` case before `--version`, and replace the help line

Add this case (after the `doctor)` line, before `--version|-v)`):
```bash
  drafts)
    if [ "$#" -gt 1 ]; then printf 'brainstem drafts 只收一個參數\n' >&2; exit 1
    elif [ "$#" -eq 0 ]; then exec bun "$ENGINE_HOME/lib/drafts.mjs"
    elif [ "$1" = "--default" ]; then exec bun "$ENGINE_HOME/lib/config.mjs" unset-drafts
    else exec bun "$ENGINE_HOME/lib/config.mjs" set-drafts "$1"; fi ;;
```
Replace the help line:
```bash
  ""|--help|-h) printf 'brainstem <where | use <dir> | init <dir> | check [--dup <src>] | doctor | --version>\n' ;;
```
with:
```bash
  ""|--help|-h) printf '%s\n' \
    'brainstem where                     印目前的腦路徑' \
    'brainstem use <dir>                 設預設腦(需 .brainroot)' \
    'brainstem init <dir>                從範本開新腦' \
    'brainstem check [--dup <src>]       體檢 / 去重' \
    'brainstem doctor                    環境預檢' \
    'brainstem drafts [<dir>|--default]  查 / 設 / 清 草稿落點' \
    'brainstem --version                 印引擎版號' ;;
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bash bin/test-drafts-cli.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add bin/brainstem bin/test-drafts-cli.sh
git commit -m "feat: brainstem drafts 子命令(arity-guard)+ 多行 --help"
```

---

## Task 4: `check.mjs` — drafts count via `resolveDrafts()`

**Files:**
- Modify: `check.mjs:6-8` (imports), `check.mjs:72`
- Create: `bin/test-check-drafts.sh`

**Interfaces:**
- Consumes: `resolveDrafts()` from `./lib/drafts.mjs` (Task 1).

- [ ] **Step 1: Write the failing test** — `bin/test-check-drafts.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"; mkdir -p "$B/notes" "$B/entities"
CFG="$(mktemp -d)"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"; mkdir -p "$D"; : > "$D/a.md"; : > "$D/b.md"
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/check.mjs" || true)"
echo "$OUT" | grep -q "drafts:2" || { echo "FAIL: check should count 2 drafts from pinned dir"; echo "$OUT"; exit 1; }
rm -rf "$B" "$CFG" "$(dirname "$D")"
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-check-drafts.sh`
Expected: FAIL (current check counts `$BRAIN/docs/drafts` = 0, not the pinned dir's 2).

- [ ] **Step 3: Edit `check.mjs`**

Add the import after the existing `import { findBrain } from "./lib/find-brain.mjs";` line:
```js
import { resolveDrafts } from "./lib/drafts.mjs";
```
Replace line 72:
```js
const drafts = existsSync(join(BRAIN, "docs/drafts")) ? readdirSync(join(BRAIN, "docs/drafts")).filter((f) => f.endsWith(".md")).length : 0;
```
with:
```js
const draftsDir = resolveDrafts();
const drafts = draftsDir && existsSync(draftsDir) ? readdirSync(draftsDir).filter((f) => f.endsWith(".md")).length : 0;
```

- [ ] **Step 4: Run new test + regression**

Run: `bash bin/test-check-drafts.sh && bash bin/test-drafts.sh`
Expected: both `PASS`.

- [ ] **Step 5: Commit**

```bash
git add check.mjs bin/test-check-drafts.sh
git commit -m "feat: check.mjs 草稿計數改用 resolveDrafts(外接 drafts 也一致)"
```

---

## Task 5: `doctor.mjs` + `init.mjs` — show drafts & pinned notice

**Files:**
- Modify: `doctor.mjs` (import; the `!BRAIN` block at lines 9-10; info section after line 31), `init.mjs` (imports; the pointer-set line 26)
- Create: `bin/test-drafts-notice.sh`

**Interfaces:**
- Consumes: `resolveDrafts()`, `pinnedDraftsDir()`, `draftsPinnedNotice()` from `./lib/drafts.mjs`; `currentBrain()` from `./lib/config.mjs`.

- [ ] **Step 1: Write the failing test** — `bin/test-drafts-notice.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"; printf '# lens\n- x\n' > "$B/lens.md"
CFG="$(mktemp -d)"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"; mkdir -p "$D"

# doctor:未 pin → 顯示「預設,跟腦」
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/doctor.mjs" || true)"
echo "$OUT" | grep -q "drafts: $B/docs/drafts" || { echo "FAIL: doctor should show default drafts"; echo "$OUT"; exit 1; }

# doctor:pin → 顯示 pinned
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/doctor.mjs" || true)"
echo "$OUT" | grep -q "drafts: $D(pinned)" || { echo "FAIL: doctor should show pinned drafts"; echo "$OUT"; exit 1; }

# init:draftsDir 已 pin(且 config 無 brain key)→ init 仍設 brain key,且輸出含提醒
NBP="$(mktemp -d)"; NB="$NBP/nb"
OUT="$(XDG_CONFIG_HOME="$CFG" bun "$ROOT/init.mjs" "$NB")"
echo "$OUT" | grep -q "不隨腦切換" || { echo "FAIL: init should warn when drafts pinned"; echo "$OUT"; exit 1; }
grep -q '"brain"' "$CFG/brainstem/config.json" || { echo "FAIL: init should set brain key even when config already has draftsDir"; exit 1; }

rm -rf "$B" "$CFG" "$(dirname "$D")" "$NBP"
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-drafts-notice.sh`
Expected: FAIL (doctor prints no drafts line; init skips brain-set because config file already exists).

- [ ] **Step 3: Edit `doctor.mjs`**

Add import after `import { findBrain } from "./lib/find-brain.mjs";`:
```js
import { resolveDrafts, pinnedDraftsDir } from "./lib/drafts.mjs";
```
Replace lines 9-10:
```js
const BRAIN = findBrain();
if (!BRAIN) { process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init/use。\n"); process.exit(1); }
```
with:
```js
const BRAIN = findBrain();
const pinnedDrafts = pinnedDraftsDir();
if (!BRAIN) {
  if (pinnedDrafts) console.log(`drafts: ${pinnedDrafts}(pinned,目前無腦)`);
  process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init/use。\n");
  process.exit(1);
}
```
After the `Bun.which("brainstem") ? ...` line (currently line 31) add:
```js
info(`drafts: ${resolveDrafts()}${pinnedDrafts ? "(pinned)" : "(預設,跟腦)"}`);
```

- [ ] **Step 4: Edit `init.mjs`**

Replace the imports block (lines 5-6):
```js
import { setBrain } from "./lib/config.mjs";
import { configPath } from "./lib/find-brain.mjs";
```
with:
```js
import { setBrain, currentBrain } from "./lib/config.mjs";
import { draftsPinnedNotice } from "./lib/drafts.mjs";
```
Replace line 26:
```js
if (!existsSync(configPath())) setBrain(abs);
```
with:
```js
if (!currentBrain()) setBrain(abs);
else { const n = draftsPinnedNotice(); if (n) process.stdout.write(n + "\n"); }
```

- [ ] **Step 5: Run new test + regressions**

Run: `bash bin/test-drafts-notice.sh && bash bin/test-doctor.sh && bash bin/test-init.sh`
Expected: all `PASS` (doctor's three cases still hold; init still scaffolds + first-brain works).

- [ ] **Step 6: Commit**

```bash
git add doctor.mjs init.mjs bin/test-drafts-notice.sh
git commit -m "feat: doctor 顯示 drafts;init 以 brain key 判定 + pinned 提醒"
```

---

## Task 6: `skills/brainstem-synthesize/SKILL.md` — route output to `$DRAFTS`

**Files:**
- Modify: `skills/brainstem-synthesize/SKILL.md` (`:3`, `:15`, `:20`, `:24`, `:39`, `:40`; add a `DRAFTS=` line)
- Modify: `bin/test-skills-wiring.sh` (append a synthesize-drafts block)

**Interfaces:** consumes `brainstem drafts` (Tasks 1, 3) at runtime.

- [ ] **Step 1: Extend the wiring test** — append to `bin/test-skills-wiring.sh` (before its final `echo "PASS"`)

```bash
# synthesize drafts 落點改用 $DRAFTS
SY="$ROOT/skills/brainstem-synthesize/SKILL.md"
grep -q 'DRAFTS="\$(brainstem drafts)"' "$SY" || { echo "FAIL: synthesize missing DRAFTS=\$(brainstem drafts)"; exit 1; }
grep -q 'mkdir -p "\$DRAFTS"' "$SY" || { echo "FAIL: synthesize missing mkdir -p \$DRAFTS"; exit 1; }
! grep -q '\$BRAIN/docs/drafts' "$SY" || { echo "FAIL: synthesize still references \$BRAIN/docs/drafts"; exit 1; }
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-skills-wiring.sh`
Expected: FAIL (synthesize still uses `$BRAIN/docs/drafts`, no `DRAFTS=`).

- [ ] **Step 3: Edit `skills/brainstem-synthesize/SKILL.md`**

After the locate-brain fenced block (ends at line 13), the line 15 currently reads:
```markdown
產出落點固定 `$BRAIN/docs/drafts/`。
```
Replace it with:
```markdown
產出落點 = `brainstem drafts` 解析的目錄(未設 draftsDir → 預設 `$BRAIN/docs/drafts/`):
```bash
DRAFTS="$(brainstem drafts)" || exit 1
```
```
Then apply these in-place replacements:
- Line 20 `先掃 \`$BRAIN/docs/drafts/\`` → `先掃 \`$DRAFTS/\``
- Line 24 `**寫草稿** → \`$BRAIN/docs/drafts/<slug>.md\`` → `**寫草稿** → \`$DRAFTS/<slug>.md\`(寫前先 \`mkdir -p "$DRAFTS"\`)`
- Line 39 `→ docs/drafts/<slug>.md(待 review)` → `→ $DRAFTS/<slug>.md(待 review)`
- Line 40 `草稿在 \`docs/drafts/\`` → `草稿在 \`$DRAFTS/\``
- Line 3 (description) `落到 docs/drafts/` → `落到設定的 drafts 目錄(預設 $BRAIN/docs/drafts/)`

- [ ] **Step 4: Run it, verify it passes**

Run: `bash bin/test-skills-wiring.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add skills/brainstem-synthesize/SKILL.md bin/test-skills-wiring.sh
git commit -m "feat: synthesize 落點改用 brainstem drafts($DRAFTS)"
```

---

## Task 7: Docs + full-suite green

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `_brain-template/CLAUDE.md`

**Interfaces:** none downstream (terminal task).

- [ ] **Step 1: `README.md`** — after the `brainstem check ... brainstem doctor` line (line 24), add:

```markdown
- `brainstem drafts [<dir> | --default]` — 查 / 設 / 清 synthesize 草稿落點(未設 = `$BRAIN/docs/drafts`)
```

- [ ] **Step 2: `CLAUDE.md`** (engine) — in the CLI line (line 9), change `where|use|init|check|doctor|--version` to include `drafts`:

```markdown
- **CLI**:`bin/brainstem`(POSIX 分派)→ `where|use|init|check|doctor|drafts|--version`。
```

- [ ] **Step 3: `_brain-template/CLAUDE.md`** — after the `brainstem where / brainstem use <dir>` tool line (line 33), add:

```markdown
- `brainstem drafts [<dir> | --default]` — 查 / 設 / 清 草稿落點(未設 = `$BRAIN/docs/drafts`)。
```

- [ ] **Step 4: Run the full suite**

Run:
```bash
for t in find-brain config doctor init install skills-wiring ac4 drafts config-merge drafts-cli check-drafts drafts-notice; do
  printf '%-16s ' "$t:"; bash bin/test-$t.sh
done
```
Expected: every line prints `PASS`.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md _brain-template/CLAUDE.md
git commit -m "docs: 補 brainstem drafts 用法(README / 引擎+腦版 CLAUDE.md)"
```

---

## Self-Review (author checklist — completed at plan-writing time)

- **Spec coverage:** A(resolveDrafts/sync/corrupt)→T1; B(read-merge-write + setBrain fix + setters)→T2; C(dispatch + arity + multi-help)→T3; D(check + synthesize)→T4/T6; E(doctor + use/init notice)→T2(setBrain)+T5(doctor/init); F(docs)→T7; G(install unchanged, rerun)→stated in Global Constraints. Tests 1–10 → T1(1,5,6,corrupt)/T2(2,3,4,9-setBrain)/T3(7)/T4(8)/T5(9-init,doctor)/T6(wiring)/T7(10 full suite incl. regressions).
- **Latent bug fixed:** config can now exist with only `draftsDir`, so T5 gates init's brain-set on `currentBrain()` (the `brain` key), not file presence — covered by test-drafts-notice.sh's brain-key assertion.
- **Placeholder scan:** none; every code/edit step shows real content or exact old→new.
- **Type/name consistency:** `resolveDrafts`/`pinnedDraftsDir`/`draftsPinnedNotice` (T1) consumed verbatim in T2/T4/T5; `currentBrain`/`setDrafts`/`unsetDrafts` (T2) consumed in T3(CLI)/T5; config import path `./drafts.mjs` from config.mjs and `./lib/drafts.mjs` from check/doctor/init are correct relative to each file's location; dedup-free dirs (`mkdir -p "$DRAFTS"`) consistent between SKILL.md and config setter.
- **No import cycle:** drafts.mjs → find-brain.mjs; config.mjs → find-brain.mjs + drafts.mjs; init/check/doctor → lib/*. No cycle.
```
