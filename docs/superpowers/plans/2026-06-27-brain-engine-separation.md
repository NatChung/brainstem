# Brain–Engine Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the brainstem engine location-agnostic so a user's private brain (notes/lens/`.brainroot`) lives outside the public engine repo, the engine installs globally by copy, and the repo can be deleted after install.

**Architecture:** Brain location resolves through one helper (`lib/find-brain.mjs`: `BRAIN_DIR` → cwd-walk for `.brainroot` → global config pointer → error). `install.sh` *copies* engine + skills into stable, repo-independent homes (`~/.local/share/brainstem`, `~/.claude/skills`, `~/.local/bin/brainstem`). A POSIX-shell `brainstem` dispatcher fronts `where/use/init/check/doctor/--version`. New brains are scaffolded by `brainstem init <dir>` from `_brain-template/`.

**Tech Stack:** Bun (runs `.mjs` directly; `import.meta.main`, `Bun.which`, `Bun.version`), POSIX bash, markdown skills.

## Global Constraints

- Spec of record: `docs/superpowers/specs/2026-06-27-brain-engine-separation-design.md`. Every task implicitly inherits it.
- **No symlinks, no baked repo path, no Claude Code plugin.** Install = copy; dispatcher computes `ENGINE_HOME` from XDG at runtime.
- `ENGINE_HOME = ${XDG_DATA_HOME:-$HOME/.local/share}/brainstem`. Config = `${XDG_CONFIG_HOME:-$HOME/.config}/brainstem/config.json`, format `{ "brain": "<abs>" }`. CLI dir = `$HOME/.local/bin`.
- Brain-resolution precedence (exact): **1** `BRAIN_DIR` (trusted as-is, NOT required to contain `.brainroot`) → **2** cwd upward `.brainroot` → **3** config pointer (only if its path still contains `.brainroot`) → **4** error to **stderr**, exit 1.
- Errors go to stderr; resolved paths go to stdout (skills capture `$(brainstem where)`).
- Tests are bash scripts under `bin/`, run with `bash bin/<name>.sh`, print `PASS`/`FAIL`, exit non-zero on failure. Follow that existing style; no test framework.
- Language: code comments/docs in 中文 per repo convention. Commit messages end with the repo's Co-Authored-By trailer.
- Work happens on branch `design/brain-engine-separation` (already checked out).

## File Structure

| File | Responsibility |
|---|---|
| `VERSION` | Single source of engine version string (e.g. `0.1.0`). |
| `lib/find-brain.mjs` | Resolve brain dir (precedence above); exports `findBrain()` + `configPath()`; runs as CLI = `brainstem where`. |
| `lib/config.mjs` | Read/write the global pointer; exports `setBrain(dir)`; runs as CLI = `config.mjs set <dir>`. |
| `init.mjs` | `brainstem init <dir>`: copy `_brain-template/` → dir, refuse non-empty/existing brain, set pointer if unset. |
| `check.mjs` / `doctor.mjs` | Existing tools; switch brain resolution to `findBrain()`. doctor also checks `brainstem` on PATH + prints VERSION. |
| `bin/brainstem` | POSIX dispatcher (repo source; copied to `~/.local/bin` by install). |
| `install.sh` | Copy engine + skills + dispatcher to global homes; PATH warning; idempotent = upgrade. |
| `_brain-template/**` | Skeleton of a fresh brain (seeds, unconfigured lens, brain-version CLAUDE.md, `_templates/`, `_index.md`, `.gitignore`, placeholders). |
| `skills/brainstem-*/SKILL.md` | Locate brain via `brainstem where` (+PATH probe); call `brainstem check`/`brainstem check --dup`; query answers "where is my brain". |
| `bin/test-*.sh` | Shell tests; add find-brain/config/init/skills-wiring/ac4; fix install test; retire brain-root. |
| `CLAUDE.md` (root) | Rewrite → engine/contributor doc. |
| `README.md`, `package.json` | New install/structure/upgrade/migration; drop `brain`/`doctor` scripts. |

---

## Phase 1 — Engine core

### Task 1: `VERSION` + `lib/find-brain.mjs` (resolver + `where` CLI)

**Files:**
- Create: `VERSION`, `lib/find-brain.mjs`, `bin/test-find-brain.sh`

**Interfaces:**
- Produces: `findBrain(): string｜null` and `configPath(): string` from `lib/find-brain.mjs`. Running the file directly prints the resolved abs path to stdout (exit 0) or an error to stderr (exit 1).

- [ ] **Step 1: Write the failing test** — `bin/test-find-brain.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FB="$ROOT/lib/find-brain.mjs"

# 1. BRAIN_DIR 直接採信(即使無 .brainroot)
D1="$(mktemp -d)"
OUT="$(BRAIN_DIR="$D1" bun "$FB")"; [ "$OUT" = "$D1" ] || { echo "FAIL: BRAIN_DIR"; exit 1; }

# 2. cwd 上行找 .brainroot
B="$(mktemp -d)"; : > "$B/.brainroot"; mkdir -p "$B/sub"
OUT="$(cd "$B/sub" && env -u BRAIN_DIR bun "$FB")"; [ "$OUT" = "$B" ] || { echo "FAIL: cwd-walk got '$OUT'"; exit 1; }

# 3. 全域指標(指向含 .brainroot 的腦)
CFGHOME="$(mktemp -d)"; mkdir -p "$CFGHOME/brainstem"
printf '{ "brain": "%s" }\n' "$B" > "$CFGHOME/brainstem/config.json"
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFGHOME" bun "$FB")"
[ "$OUT" = "$B" ] || { echo "FAIL: config pointer got '$OUT'"; exit 1; }

# 4. 都沒有 → exit 1 + 訊息走 stderr(stdout 空)
EMPTY="$(mktemp -d)"
if OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$EMPTY" bun "$FB" 2>/dev/null)"; then echo "FAIL: should exit 1"; exit 1; fi
[ -z "${OUT:-}" ] || { echo "FAIL: path should not go to stdout"; exit 1; }

rm -rf "$D1" "$B" "$CFGHOME" "$EMPTY"
echo "PASS"
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash bin/test-find-brain.sh`
Expected: FAIL (find-brain.mjs does not exist → bun error).

- [ ] **Step 3: Create `VERSION`**

```
0.1.0
```

- [ ] **Step 4: Implement `lib/find-brain.mjs`**

```js
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
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `bash bin/test-find-brain.sh`
Expected: `PASS`

- [ ] **Step 6: Commit**

```bash
git add VERSION lib/find-brain.mjs bin/test-find-brain.sh
git commit -m "feat: lib/find-brain.mjs — 統一腦解析 + where CLI + VERSION"
```

---

### Task 2: `lib/config.mjs` (global pointer writer)

**Files:**
- Create: `lib/config.mjs`, `bin/test-config.sh`

**Interfaces:**
- Consumes: `configPath()` from `lib/find-brain.mjs`.
- Produces: `setBrain(dir)` — normalizes `dir` to absolute, requires `.brainroot`, `mkdir -p`s the config dir, writes `{ "brain": "<abs>" }`. Running directly: `config.mjs set <dir>`.

- [ ] **Step 1: Write the failing test** — `bin/test-config.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$ROOT/lib/config.mjs"
FB="$ROOT/lib/find-brain.mjs"
CFGHOME="$(mktemp -d)"
B="$(mktemp -d)"; : > "$B/.brainroot"

# set 寫入指標,且 find-brain 隨後解析得到它
XDG_CONFIG_HOME="$CFGHOME" bun "$CFG" set "$B" >/dev/null
grep -q "$B" "$CFGHOME/brainstem/config.json" || { echo "FAIL: pointer not written"; exit 1; }
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFGHOME" bun "$FB")"
[ "$OUT" = "$B" ] || { echo "FAIL: resolve got '$OUT'"; exit 1; }

# 拒絕非腦目錄
NOPE="$(mktemp -d)"
if XDG_CONFIG_HOME="$CFGHOME" bun "$CFG" set "$NOPE" >/dev/null 2>&1; then echo "FAIL: should reject non-brain"; exit 1; fi

rm -rf "$CFGHOME" "$B" "$NOPE"
echo "PASS"
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash bin/test-config.sh`
Expected: FAIL (config.mjs missing).

- [ ] **Step 3: Implement `lib/config.mjs`**

```js
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash bin/test-config.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add lib/config.mjs bin/test-config.sh
git commit -m "feat: lib/config.mjs — 全域腦指標讀寫"
```

---

### Task 3: Switch `check.mjs` + `doctor.mjs` to `findBrain()`

**Files:**
- Modify: `check.mjs:6-10`, `doctor.mjs:3-7` and `doctor.mjs:24-26`
- Test: existing `bin/test-doctor.sh` (must stay green, unchanged)

**Interfaces:**
- Consumes: `findBrain()` from `./lib/find-brain.mjs` (relative import works post-copy since `lib/` is copied alongside).

- [ ] **Step 1: Confirm the existing doctor test still describes desired behavior**

Run: `bash bin/test-doctor.sh`
Expected: `PASS` today (baseline). Cases: A configured→0, B unconfigured lens→1, C `BRAIN_DIR` to dir w/o `.brainroot`→1 (doctor's own `.brainroot` check fails it — find-brain trusts `BRAIN_DIR`, so this case keeps working after the change).

- [ ] **Step 2: Edit `check.mjs`** — replace the brain pin (lines 6-10)

Old:
```js
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const BRAIN = dirname(fileURLToPath(import.meta.url));
```
New:
```js
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { findBrain } from "./lib/find-brain.mjs";

const BRAIN = findBrain();
if (!BRAIN) { process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init/use。\n"); process.exit(1); }
```
(`fileURLToPath`/`dirname` were only used for `BRAIN`; drop them.)

- [ ] **Step 3: Edit `doctor.mjs`** — resolver + PATH check + VERSION

Replace lines 3-7:
```js
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const BRAIN = process.env.BRAIN_DIR || dirname(fileURLToPath(import.meta.url));
```
with:
```js
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { findBrain } from "./lib/find-brain.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const BRAIN = findBrain();
if (!BRAIN) { process.stderr.write("找不到腦 — cd 進一顆,或 brainstem init/use。\n"); process.exit(1); }
```
Then after the `info(\`Bun ${Bun.version}\`);` line (currently line 25) add:
```js
const verFile = join(HERE, "VERSION");
info(`brainstem ${existsSync(verFile) ? readFileSync(verFile, "utf8").trim() : "(no VERSION)"}`);
Bun.which("brainstem") ? ok("brainstem 指令在 PATH") : warn("brainstem 不在 PATH — 把 ~/.local/bin 加進 PATH 或重跑 install.sh");
```

- [ ] **Step 4: Run the doctor test, verify still green**

Run: `bash bin/test-doctor.sh`
Expected: `PASS` (all three cases). Note: when run via `BRAIN_DIR`, find-brain returns it directly; doctor's own checklist handles the `.brainroot`/lens checks exactly as before.

- [ ] **Step 5: Sanity-run check against a temp brain**

Run:
```bash
T="$(mktemp -d)"; : > "$T/.brainroot"; mkdir -p "$T/notes" "$T/entities"
( cd "$T" && bun "$(git rev-parse --show-toplevel)/check.mjs" ) ; rm -rf "$T"
```
Expected: prints a health report for `$T` (0 notes), exit 0 — i.e. it resolved the *cwd* brain, not the engine dir.

- [ ] **Step 6: Commit**

```bash
git add check.mjs doctor.mjs
git commit -m "refactor: check/doctor 改用 find-brain;doctor 加 PATH/VERSION 檢"
```

---

### Task 4: `bin/brainstem` dispatcher + copy-based `install.sh` + fix tests

**Files:**
- Create: `bin/brainstem`
- Rewrite: `install.sh`
- Modify: `bin/test-install.sh`
- Delete: `bin/brain-root.sh`, `bin/test-brain-root.sh` (superseded by find-brain + its test)

**Interfaces:**
- Produces: global `brainstem` command with subcommands `where｜use <dir>｜init <dir>｜check [--dup <src>]｜doctor｜--version｜--help`. install copies engine to `ENGINE_HOME`, skills (real files) to `~/.claude/skills`, dispatcher to `~/.local/bin/brainstem`.

- [ ] **Step 1: Rewrite `bin/test-install.sh`** (the failing test for the copy model)

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP" XDG_DATA_HOME="$TMP/share" XDG_CONFIG_HOME="$TMP/config"
# 裝兩次(idempotent)
bash "$ROOT/install.sh" >/dev/null
bash "$ROOT/install.sh" >/dev/null
# skills 是真實檔、非 symlink
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  D="$TMP/.claude/skills/$s"
  [ -e "$D" ] && [ ! -L "$D" ] || { echo "FAIL: $s not a real dir"; exit 1; }
  [ -f "$D/SKILL.md" ] || { echo "FAIL: $s/SKILL.md missing"; exit 1; }
done
# 引擎複製進 ENGINE_HOME
for f in check.mjs doctor.mjs init.mjs lib/find-brain.mjs lib/config.mjs _brain-template/.brainroot VERSION; do
  [ -e "$TMP/share/brainstem/$f" ] || { echo "FAIL: ENGINE_HOME missing $f"; exit 1; }
done
# CLI dispatcher 可跑
[ -x "$TMP/.local/bin/brainstem" ] || { echo "FAIL: brainstem CLI missing"; exit 1; }
"$TMP/.local/bin/brainstem" --version | grep -q . || { echo "FAIL: --version empty"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-install.sh`
Expected: FAIL (old install.sh symlinks; no dispatcher; no ENGINE_HOME copy).

- [ ] **Step 3: Create `bin/brainstem` dispatcher**

```bash
#!/usr/bin/env bash
# brainstem CLI — 純分派。ENGINE_HOME 由 XDG 在 runtime 計算(不 bake repo 路徑)。
set -euo pipefail
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
cmd="${1:-}"; [ "$#" -gt 0 ] && shift || true
case "$cmd" in
  where)        exec bun "$ENGINE_HOME/lib/find-brain.mjs" ;;
  use)          exec bun "$ENGINE_HOME/lib/config.mjs" set "$@" ;;
  init)         exec bun "$ENGINE_HOME/init.mjs" "$@" ;;
  check)        exec bun "$ENGINE_HOME/check.mjs" "$@" ;;
  doctor)       exec bun "$ENGINE_HOME/doctor.mjs" "$@" ;;
  --version|-v) cat "$ENGINE_HOME/VERSION" ;;
  ""|--help|-h) printf 'brainstem <where | use <dir> | init <dir> | check [--dup <src>] | doctor | --version>\n' ;;
  *)            printf 'unknown subcommand: %s\n' "$cmd" >&2; exit 1 ;;
esac
```

- [ ] **Step 4: Rewrite `install.sh` (copy model)**

```bash
#!/usr/bin/env bash
# 複製式全域安裝:引擎 → ENGINE_HOME、skills → ~/.claude/skills、CLI → ~/.local/bin。
# idempotent = 升級。裝完此 repo 可刪。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"

OLD="$(cat "$ENGINE_HOME/VERSION" 2>/dev/null || echo none)"
mkdir -p "$ENGINE_HOME" "$SKILLS" "$BIN"

# 引擎 runtime(先清舊 lib/_brain-template 再複製,避免殘檔)
rm -rf "$ENGINE_HOME/lib" "$ENGINE_HOME/_brain-template"
cp -R "$ROOT/check.mjs" "$ROOT/doctor.mjs" "$ROOT/init.mjs" \
      "$ROOT/lib" "$ROOT/_brain-template" "$ROOT/VERSION" "$ENGINE_HOME/"

# skills(真實檔、非 symlink)
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  rm -rf "$SKILLS/$s"
  cp -R "$ROOT/skills/$s" "$SKILLS/$s"
  echo "copied $SKILLS/$s"
done

# CLI dispatcher
cp "$ROOT/bin/brainstem" "$BIN/brainstem"
chmod +x "$BIN/brainstem"

NEW="$(cat "$ROOT/VERSION")"
echo "brainstem $OLD → $NEW 已安裝(engine: $ENGINE_HOME)"
echo "下一步:brainstem init <你的私有腦目錄>"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "⚠ $BIN 不在 PATH — 加進 shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
```

- [ ] **Step 5: Delete superseded scripts**

```bash
git rm bin/brain-root.sh bin/test-brain-root.sh
```

- [ ] **Step 6: Run the install test, verify it passes**

Run: `bash bin/test-install.sh`
Expected: `PASS`

- [ ] **Step 7: Commit**

```bash
git add bin/brainstem install.sh bin/test-install.sh
git commit -m "feat: 複製式 install.sh + brainstem dispatcher;退役 brain-root.sh"
```

> ⚠️ `_brain-template/` does not exist yet, so Step 6's check for `_brain-template/.brainroot` will fail until Task 5. **Execute Task 5 before re-running `bin/test-install.sh` as a gate.** If running strictly task-by-task, temporarily comment the `_brain-template/.brainroot` line in the test, then restore it after Task 5. (Subagent-driven execution should sequence 5 immediately after 4 and re-run install test at the end of 5.)

---

## Phase 2 — Template + init

### Task 5: Assemble `_brain-template/`

**Files:**
- Create: `_brain-template/.brainroot`, `_brain-template/lens.md`, `_brain-template/log.md`, `_brain-template/.gitignore`, `_brain-template/_index.md`, `_brain-template/CLAUDE.md`, `_brain-template/_templates/{note.md,entity.md}`, `_brain-template/notes/{.gitkeep,atomic-note-one-idea.md}`, `_brain-template/entities/{.gitkeep,brainstem.md}`, `_brain-template/sources/transcripts/.gitkeep`, `_brain-template/docs/drafts/.gitkeep`

**Interfaces:**
- Produces: a complete unconfigured brain skeleton that `init.mjs` (Task 6) copies verbatim.

- [ ] **Step 1: Scaffold dirs and move existing seed assets**

```bash
mkdir -p _brain-template/_templates _brain-template/notes _brain-template/entities \
         _brain-template/sources/transcripts _brain-template/docs/drafts
# 既有 seed 內容直接搬(保留 git 歷史)
git mv notes/atomic-note-one-idea.md _brain-template/notes/atomic-note-one-idea.md
git mv entities/brainstem.md          _brain-template/entities/brainstem.md
git mv _templates/note.md             _brain-template/_templates/note.md
git mv _templates/entity.md           _brain-template/_templates/entity.md
git mv _index.md                      _brain-template/_index.md
cp .gitignore                         _brain-template/.gitignore
: > _brain-template/notes/.gitkeep
: > _brain-template/entities/.gitkeep
: > _brain-template/sources/transcripts/.gitkeep
: > _brain-template/docs/drafts/.gitkeep
```

- [ ] **Step 2: `.brainroot` + `log.md`**

```bash
: > _brain-template/.brainroot
printf '# brain log\n\n' > _brain-template/log.md
```

- [ ] **Step 3: Unconfigured `lens.md` from git HEAD** (not this session's edited copy)

```bash
git show HEAD:lens.md > _brain-template/lens.md
grep -q "LENS_UNCONFIGURED" _brain-template/lens.md || { echo "ERROR: template lens must keep sentinel"; exit 1; }
```

- [ ] **Step 4: Brain-version `CLAUDE.md`** — create `_brain-template/CLAUDE.md`

```markdown
# 你的腦(brainstem · Claude Code 自動載入)

> 個人知識圖譜。中文為主、英文輔助。`notes/` 原子筆記彼此 `[[wikilink]]`,`entities/` 放人/組織/產品/工具,`docs/drafts/` 放合成草稿。

## 這顆腦在哪
腦 = 含 `.brainroot` 的這個目錄。引擎(skills + `brainstem` CLI)已全域安裝,不在這裡。
- 查腦位置:`brainstem where` · 改預設腦:`brainstem use <dir>`。

## 首次設定(對話式 onboarding)
**每次 session 載入先讀本目錄 `lens.md`**——若仍含 `<!-- LENS_UNCONFIGURED -->`,在執行任何請求前先跑 onboarding。

**第 0 步:環境預檢**——跑 `brainstem doctor` 確認就緒(`.brainroot` / `lens.md` / `brainstem` 在 PATH / `yt-dlp` / whisper)。紅項先補(doctor 唯讀)。

**先看有沒有既有圖**:若本目錄 `notes/` 已有非 seed 的 `.md`(seed = 只有 `atomic-note-one-idea.md`)→ 印「找到既有 N 則 note,沿用、不重建」,跳過「建第一則」;`lens.md` 仍含 sentinel 才走第 1 步,否則跳到第 3 步。

1. **填 lens**——lens 改三件事:ingest 收料抽什麼、query 查時先浮什麼、synthesize 寫時什麼口吻。三題各給範例 + 一條【推薦】,不知道用推薦的:
   - **(收料)留什麼、丟什麼?** 例:留可操作判準丟鋪陳 · **【推薦】先都留,之後再篩**
   - **(查)先看到什麼?** **【推薦】先給結論 + 幾個關鍵 note** · 先給反方 · 先給原始出處
   - **(寫)像誰說話?** **【推薦】第一人稱、直白、不誇大** · 條列極簡 · 像教學帶例子
   出口:挑範例 / 說「用推薦的」(整步「全用推薦」)/ 說「我貼 lens」。把回答寫進 `lens.md` 三段,**移除 `<!-- LENS_UNCONFIGURED -->` 那行**。「全用推薦」= 收料「先都留,之後再篩」/ 查「先給結論 + 幾個關鍵 note」/ 寫「第一人稱、直白、不誇大」。
2. **餵第一個來源**:用 `brainstem-ingest` 餵一個 URL 或一段想法,建第一則 note。
3. **體檢**:`brainstem check`,確認 0 孤島 / 0 斷鏈。

## 原子筆記紀律
- 一則 note 一個想法;過長就拆。
- 連結在 ingest 當下就建(非查詢時)——這是跟 RAG 的根本差別。
- 萃取「理解被校準後的那一兩句」+ 最可操作的判準,不搬運原文。
- seed 的 `atomic-note-one-idea` / `brainstem` 兩頁是示範,看懂後可刪。

## 工具
- `brainstem check` — 體檢;`brainstem check --dup <來源>` 去重。
- `brainstem doctor` — 環境體檢。
- `brainstem where` / `brainstem use <dir>` — 查 / 改腦位置。
- 三個 skill:`brainstem-ingest`(餵料)/ `brainstem-query`(查)/ `brainstem-synthesize`(產草稿)。

## 語言政策
- 本檔與 skill 指令用中文;你的 notes / lens 語言自訂(英文、中文或混用)。
```

- [ ] **Step 5: Verify template is complete**

Run:
```bash
test -f _brain-template/.brainroot && test -f _brain-template/lens.md \
 && test -f _brain-template/_index.md && test -f _brain-template/_templates/note.md \
 && test -f _brain-template/CLAUDE.md && test -d _brain-template/sources/transcripts \
 && echo "TEMPLATE OK"
```
Expected: `TEMPLATE OK`

- [ ] **Step 6: Re-run the install test (now that `_brain-template/` exists)**

Run: `bash bin/test-install.sh`
Expected: `PASS` (restore the `_brain-template/.brainroot` assertion if it was temporarily commented in Task 4).

- [ ] **Step 7: Commit**

```bash
git add -A _brain-template
git add notes entities _templates _index.md   # 記錄被 git mv 搬走的原檔刪除
git commit -m "feat: _brain-template/ 新腦骨架(搬入 seed、未設定 lens、腦版 CLAUDE.md)"
```

---

### Task 6: `init.mjs` + `brainstem init`

**Files:**
- Create: `init.mjs`, `bin/test-init.sh`

**Interfaces:**
- Consumes: `setBrain` from `lib/config.mjs`, `configPath` from `lib/find-brain.mjs`, the `_brain-template/` dir sitting next to `init.mjs` (in repo during test; in `ENGINE_HOME` after install — both have `_brain-template/` as a sibling).
- Produces: `brainstem init <dir>` → scaffolded brain + (if pointer unset) pointer set to it.

- [ ] **Step 1: Write the failing test** — `bin/test-init.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/init.mjs"
CFGHOME="$(mktemp -d)"
TB="$(mktemp -d)/tb"   # 不存在的子目錄

# init 建腦
XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$TB" >/dev/null
for f in .brainroot lens.md CLAUDE.md _index.md _templates/note.md notes/atomic-note-one-idea.md sources/transcripts docs/drafts; do
  [ -e "$TB/$f" ] || { echo "FAIL: init missing $f"; exit 1; }
done
grep -q "LENS_UNCONFIGURED" "$TB/lens.md" || { echo "FAIL: lens should be unconfigured"; exit 1; }
# 指標未設定 → init 設成這顆
grep -q "$TB" "$CFGHOME/brainstem/config.json" || { echo "FAIL: pointer not set on first init"; exit 1; }

# 對已是腦的目錄 init → 拒絕
if XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$TB" >/dev/null 2>&1; then echo "FAIL: should refuse existing brain"; exit 1; fi

# 對非空非腦目錄 init → 拒絕
NE="$(mktemp -d)"; : > "$NE/x"
if XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$NE" >/dev/null 2>&1; then echo "FAIL: should refuse non-empty"; exit 1; fi

rm -rf "$CFGHOME" "$TB" "$NE"
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-init.sh`
Expected: FAIL (init.mjs missing).

- [ ] **Step 3: Implement `init.mjs`**

```js
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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash bin/test-init.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add init.mjs bin/test-init.sh
git commit -m "feat: init.mjs — brainstem init 從範本開新腦 + 首顆設預設"
```

---

## Phase 3 — Skills

### Task 7: Rewire the three skills (USE `superpowers:writing-skills`)

> **Sub-skill:** Invoke `superpowers:writing-skills` before editing, per the brain owner's instruction. Edits are markdown; keep each SKILL.md's structure/triggers intact — change only brain-location and `check.mjs` invocations, plus one query addition.

**Files:**
- Modify: `skills/brainstem-ingest/SKILL.md` (locate block lines 8-13; `:19`; `:30`)
- Modify: `skills/brainstem-query/SKILL.md` (locate block; add "where" answer)
- Modify: `skills/brainstem-synthesize/SKILL.md` (locate block; `:40`)
- Create: `bin/test-skills-wiring.sh`

**Interfaces:**
- Consumes: global `brainstem where`, `brainstem check`, `brainstem check --dup` (Tasks 1, 3, 4).

- [ ] **Step 1: Write the failing wiring test** — `bin/test-skills-wiring.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  F="$ROOT/skills/$s/SKILL.md"
  grep -q 'brainstem where' "$F" || { echo "FAIL: $s missing 'brainstem where'"; exit 1; }
  grep -q 'command -v brainstem' "$F" || { echo "FAIL: $s missing PATH probe"; exit 1; }
  ! grep -q '\$BRAIN/check.mjs' "$F" || { echo "FAIL: $s still calls \$BRAIN/check.mjs"; exit 1; }
  ! grep -q 'while \[ "\$d" != / \]' "$F" || { echo "FAIL: $s still has inline brainroot walk"; exit 1; }
done
grep -q 'brainstem check --dup' "$ROOT/skills/brainstem-ingest/SKILL.md" || { echo "FAIL: ingest dedup not rewired"; exit 1; }
grep -q 'brainstem where' "$ROOT/skills/brainstem-query/SKILL.md" || { echo "FAIL: query 'where' answer missing"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-skills-wiring.sh`
Expected: FAIL (skills still use inline walk + `$BRAIN/check.mjs`).

- [ ] **Step 3: Replace the locate block in all three SKILL.md**

In each of the three files, replace the heading + fenced block (ingest lines 8-13; same shape in query/synthesize):

Old:
```markdown
## 定位 brain(每次最先跑)
`$BRAIN` = 從 cwd 向上找到的腦根(含 `.brainroot` 的目錄):
```bash
BRAIN="$(d="$PWD"; while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done; [ -e "$d/.brainroot" ] && printf '%s' "$d")"
[ -z "$BRAIN" ] && { echo "找不到 .brainroot — 請先 cd 進你的 brain repo。"; exit 1; }
```
```
New:
```markdown
## 定位 brain(每次最先跑)
`$BRAIN` 由全域 `brainstem` 解析(BRAIN_DIR → cwd 的 `.brainroot` → 全域指標):
```bash
command -v brainstem >/dev/null || { echo "找不到 brainstem 指令 — 把 ~/.local/bin 加進 PATH 或重跑 install.sh。" >&2; exit 1; }
BRAIN="$(brainstem where)" || exit 1   # where 失敗訊息已走 stderr
```
```

- [ ] **Step 4: Rewire `check.mjs` calls**

- `skills/brainstem-ingest/SKILL.md:19`: replace `bun "$BRAIN/check.mjs" --dup <URL|影片id|路徑>` → `brainstem check --dup <URL|影片id|路徑>`.
- `skills/brainstem-ingest/SKILL.md:30`: replace `bun "$BRAIN/check.mjs"` → `brainstem check`.
- `skills/brainstem-synthesize/SKILL.md:40`: replace `bun "$BRAIN/check.mjs"` → `brainstem check`.

- [ ] **Step 5: Add the "where is my brain" answer to query skill**

In `skills/brainstem-query/SKILL.md`, after the locate block, add a bullet:
```markdown
- 被問「我腦在哪 / 怎麼換腦」時:跑 `brainstem where` 回答位置;要換預設腦引導 `brainstem use <dir>`(不替使用者擅自改)。
```

- [ ] **Step 6: Run the wiring test, verify it passes**

Run: `bash bin/test-skills-wiring.sh`
Expected: `PASS`

- [ ] **Step 7: Commit**

```bash
git add skills bin/test-skills-wiring.sh
git commit -m "feat: skills 改用 brainstem where + brainstem check;query 答腦位置"
```

---

## Phase 4 — Docs + cleanup

### Task 8: Engine `CLAUDE.md` + `README.md` + `package.json` + remove root brain + AC4 test

**Files:**
- Rewrite: `CLAUDE.md` (root → engine/contributor)
- Rewrite: `README.md`
- Modify: `package.json`
- Delete (root brain leftovers): `.brainroot`, `lens.md`, `log.md`, `sources/` (root); `notes/`, `entities/`, `_templates/`, `_index.md` already emptied by Task 5's `git mv` — remove now-empty dirs/`.gitkeep`
- Create: `bin/test-ac4.sh`

**Interfaces:** none downstream (terminal task).

- [ ] **Step 1: Write the AC4 test** — `bin/test-ac4.sh`

```bash
#!/usr/bin/env bash
# 裝進臨時 HOME,刪掉 repo 副本後,brainstem 仍能 init + check。
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/repo"; cp -R "$SRC" "$WORK"
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/home/.local/share" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/home/.local/bin:$PATH"
mkdir -p "$HOME"
bash "$WORK/install.sh" >/dev/null
rm -rf "$WORK"                      # 刪掉引擎 repo
brainstem init "$TMP/brain" >/dev/null
( cd "$TMP/brain" && brainstem check >/dev/null ) || { echo "FAIL: check broke after repo deleted"; exit 1; }
brainstem where | grep -q "$TMP/brain" || { echo "FAIL: where broke after repo deleted"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash bin/test-ac4.sh`
Expected: FAIL (root `CLAUDE.md`/brain files / package scripts may still be brain-shaped, but mainly: this is the gate proving copy-independence; run after cleanup it must pass).

- [ ] **Step 3: Rewrite root `CLAUDE.md` (engine/contributor)** — replace entire file

```markdown
# brainstem — 引擎開發(貢獻者文件)

> 這個 repo 是**引擎**,不是一顆腦。使用者的私有腦(notes/lens/`.brainroot`)住在別處,由 `brainstem init` 建立。
> **別把任何個人 note / 設定過的 lens commit 進這個公開 repo。**

## 架構
- **安裝 = 複製**(非 symlink、非 plugin):`install.sh` 把引擎複製到 `ENGINE_HOME`(`${XDG_DATA_HOME:-~/.local/share}/brainstem`)、skills 複製到 `~/.claude/skills/`、dispatcher 到 `~/.local/bin/brainstem`。裝完 repo 可刪。
- **腦解析**:`lib/find-brain.mjs` —— `BRAIN_DIR` → cwd 上行 `.brainroot` → 全域指標 `${XDG_CONFIG_HOME:-~/.config}/brainstem/config.json` → error。`check.mjs`/`doctor.mjs`/`brainstem where` 共用它。
- **CLI**:`bin/brainstem`(POSIX 分派)→ `where|use|init|check|doctor|--version`。
- **新腦骨架**:`_brain-template/`(由 `init.mjs` 複製)。

## 本機測試
```bash
bash bin/test-find-brain.sh
bash bin/test-config.sh
bash bin/test-doctor.sh
bash bin/test-install.sh
bash bin/test-init.sh
bash bin/test-skills-wiring.sh
bash bin/test-ac4.sh
# 手動冒煙:
bash install.sh && brainstem init /tmp/demo-brain && (cd /tmp/demo-brain && brainstem doctor)
```

## 升級
重 clone 最新 repo + 重跑 `install.sh`(覆寫 ENGINE_HOME、bump VERSION)。`brainstem --version` 看裝了哪版。

## 語言政策
- 本檔與 skill 指令用中文;使用者 notes/lens 語言自訂。
```

- [ ] **Step 4: Rewrite `README.md`** — replace entire file

```markdown
# brainstem

> Claude-Code-native 知識圖譜引擎:裝一次,在**任何**私有目錄養出照你思考方式生長的第二大腦。

## 它跟 NotebookLM / RAG 差在哪
1. **餵入即連結** — 每則素材在餵入當下被萃取成原子 note 並建 `[[連結]]`,圖的拓樸是你的聯想結構,不是查詢時才算的相似度。
2. **lens** — 一個 `lens.md` 寫「你怎麼判斷」,收料與生成都朝你的判準偏。

## 安裝(引擎,全域)
```bash
git clone <repo> && cd brainstem && bash install.sh
```
複製 skills + 引擎 + `brainstem` CLI 到全域。**裝完這個 repo 可以刪。** 需求:[Bun](https://bun.sh)、Claude Code。若提示 `~/.local/bin` 不在 PATH,照提示加進 shell rc。

## 開一顆腦(私有)
```bash
brainstem init ~/mybrain      # 建議放私有處 / 設私有 git remote
cd ~/mybrain                  # 用 Claude Code 開啟,說 hi → onboarding
```
onboarding:**填 `lens.md` → 餵第一個來源 → `brainstem check` 綠燈**。

## 常用
- `brainstem where` / `brainstem use <dir>` — 查 / 改預設腦位置
- `brainstem check` 體檢 · `brainstem check --dup <來源>` 去重 · `brainstem doctor` 環境檢
- skills:`brainstem-ingest` / `brainstem-query` / `brainstem-synthesize`

## 升級
重 clone + 重跑 `install.sh`;`brainstem --version` 看版號。

## 從舊版遷移(舊式「clone 即腦」)
舊 clone 根仍含 `.brainroot` 可續用:`bash install.sh` 後 `brainstem use <舊clone路徑>` 指過去,並把該 clone 設為私有。

## License
MIT
```

- [ ] **Step 5: Edit `package.json`** — drop brain/doctor scripts

Replace the `scripts` block:
```json
{
  "name": "brainstem",
  "private": false,
  "type": "module"
}
```
(Engine entry point is the global `brainstem` CLI; `bun run brain/doctor` no longer applies since the engine root is not a brain.)

- [ ] **Step 6: Remove root brain leftovers**

```bash
git rm -f .brainroot lens.md log.md
git rm -rf sources
# Task 5 已 git mv 走 notes/entities/_templates 的內容;清掉殘留佔位
git rm -f notes/.gitkeep entities/.gitkeep 2>/dev/null || true
rmdir notes entities _templates 2>/dev/null || true
```

- [ ] **Step 7: Run the full test suite + AC4**

Run:
```bash
for t in find-brain config doctor install init skills-wiring ac4; do
  echo "== $t =="; bash bin/test-$t.sh
done
```
Expected: every one prints `PASS`.

- [ ] **Step 8: Verify the engine repo carries no personal content**

Run:
```bash
test ! -e .brainroot && test ! -e lens.md && echo "engine repo clean of brain root"
git status --porcelain
```
Expected: `engine repo clean of brain root`; working tree clean after commit.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "docs: 拆引擎/腦版 CLAUDE.md、改 README、移除根腦檔;加 AC4 測試"
```

---

## Self-Review (author checklist — completed at plan-writing time)

- **Spec coverage:** A→T1/T3; B→T4; C(CLI)→T4/T6; D(install)→T4; E(template)→T5; F(skills)→T7; G(two CLAUDE.md)→T5(brain)+T8(engine); H(README/package)→T8; I(migration)→T8 README; J(lens HEAD)→T5 Step 3. `lib/config.mjs`/`where`/`use` impl→T1/T2. `bin/` fixups→T4. AC4 delete-repo→T8 test. PATH probe→T7+T3(doctor). All spec sections map to a task.
- **Placeholder scan:** no TBD/TODO; every code/edit step shows real content or an exact old→new replacement.
- **Type/name consistency:** `findBrain()`/`configPath()` (T1) consumed verbatim in T2/T3/T6; `setBrain()` (T2) consumed in T6; `ENGINE_HOME`/config path strings identical across dispatcher, install.sh, find-brain, tests; dedup form is `brainstem check --dup` everywhere (T4 dispatcher, T7 skill, tests).
- **Ordering caveat:** T4's install test asserts `_brain-template/.brainroot`, created in T5 — flagged inline; run T5's install-test step as the gate.
```
