# brainstem uninstall 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `install.sh` 加 `--uninstall`,一鍵移除 brainstem 引擎(CLI + skills + 全域 config),絕不刪腦資料,供重開 session 重測 onboarding。

**Architecture:** 在 `install.sh` 前段定義路徑常數與 `safe_rm`/`do_uninstall` 兩函式,再以 `case "${1:-}"` 分派:無參數=安裝(現有行為)、`--uninstall`=移除後 exit、未知參數=報錯。移除只針對 4 條固定引擎路徑,經 `safe_rm` 白名單防呆。`brainstem` CLI 不動。

**Tech Stack:** bash(`set -euo pipefail`)、既有 `bin/test-*.sh` 隔離測試範式(HOME/XDG → TMP)。

**Spec:** `docs/superpowers/specs/2026-06-28-brainstem-uninstall-design.md`

## Global Constraints

- 檔頂一律 `set -euo pipefail`;參數分派一律 `case "${1:-}"`(避 `set -u` unbound)。
- 移除一律走 `safe_rm`(內部 `rm -rf`,目錄與單檔皆可);`safe_rm` 白名單**只放行結尾為 `/brainstem` 或 `/brainstem-{ingest,query,synthesize}` 的路徑**,否則 `exit 1`。白名單只驗後綴、不驗前綴(定位=擋離譜空值,非擋錯 XDG)。
- 路徑常數 `ENGINE_HOME`/`SKILLS`/`BIN`/`CONFIG_HOME` 一律從 env 即時計算,安裝與移除共用同一份。
- **絕不刪腦資料**:`do_uninstall` 只刪固定 4 路徑,從不讀 config 的 `brain`/`draftsDir` 欄位。
- skill 清單 `brainstem-{ingest,query,synthesize}` 硬編於四處(install 迴圈 / `do_uninstall` / `test-install.sh` / `test-uninstall.sh`),`install.sh` 註解提醒同步。

---

### Task 1: `--uninstall` 功能(test 先行 + 改 install.sh)

**Files:**
- Create: `bin/test-uninstall.sh`
- Modify: `install.sh`(前段加 `CONFIG_HOME` 常數 + `safe_rm`/`do_uninstall` 函式 + `case "${1:-}"` 分派;安裝迴圈上方加 drift 註解)

**Interfaces:**
- Produces:
  - `safe_rm <path>` — 路徑結尾命中白名單才 `rm -rf`,否則 `exit 1`。
  - `do_uninstall` — 對 4 條固定路徑逐一 `safe_rm` + 印 `removed`/`skip`,收尾印 4 行訊息。
  - `bash install.sh --uninstall` — exit 0(移除);`bash install.sh` 無參數行為不變;未知參數 exit 1。

- [ ] **Step 1: 寫失敗測試 `bin/test-uninstall.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP" XDG_DATA_HOME="$TMP/share" XDG_CONFIG_HOME="$TMP/config"

# 裝
bash "$ROOT/install.sh" >/dev/null
# 模擬「已設過腦」:手動塞 config.json(install 不會產生它)
mkdir -p "$TMP/config/brainstem"
printf '{"brain":"%s/somebrain"}\n' "$TMP" > "$TMP/config/brainstem/config.json"

# 斷言四類目標都在
[ -f "$TMP/share/brainstem/VERSION" ] || { echo "FAIL: ENGINE_HOME missing before uninstall"; exit 1; }
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  [ -f "$TMP/.claude/skills/$s/SKILL.md" ] || { echo "FAIL: skill $s missing before uninstall"; exit 1; }
done
[ -x "$TMP/.local/bin/brainstem" ] || { echo "FAIL: CLI missing before uninstall"; exit 1; }
[ -f "$TMP/config/brainstem/config.json" ] || { echo "FAIL: config missing before uninstall"; exit 1; }

# uninstall
bash "$ROOT/install.sh" --uninstall >/dev/null

# 斷言四類目標全不存在(config 連整個目錄)
[ ! -e "$TMP/share/brainstem" ]      || { echo "FAIL: ENGINE_HOME still present"; exit 1; }
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  [ ! -e "$TMP/.claude/skills/$s" ]  || { echo "FAIL: skill $s still present"; exit 1; }
done
[ ! -e "$TMP/.local/bin/brainstem" ] || { echo "FAIL: CLI still present"; exit 1; }
[ ! -e "$TMP/config/brainstem" ]     || { echo "FAIL: config dir still present"; exit 1; }

# idempotent:再跑一次仍 exit 0
bash "$ROOT/install.sh" --uninstall >/dev/null || { echo "FAIL: second uninstall not idempotent"; exit 1; }

echo "PASS"
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `bash bin/test-uninstall.sh`
Expected: FAIL —— 現在 `install.sh` 不引用 `$1`,`--uninstall` 被忽略而照裝,故「ENGINE_HOME still present」(目標被重裝、未移除)。

- [ ] **Step 3: 改 `install.sh`** —— 在 `BIN="$HOME/.local/bin"` 那行(現 line 8)後面、`OLD=...`(現 line 10)前面,插入 `CONFIG_HOME` 常數與兩個函式 + `case` 分派。

把這段:

```bash
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"

OLD="$(cat "$ENGINE_HOME/VERSION" 2>/dev/null || echo none)"
```

改成:

```bash
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/brainstem"

# 只刪結尾像 brainstem 的固定引擎路徑(白名單只驗後綴,擋離譜空值)
safe_rm() {
  case "$1" in
    */brainstem|*/brainstem-ingest|*/brainstem-query|*/brainstem-synthesize) rm -rf "$1" ;;
    *) echo "防呆:拒刪非預期路徑 $1" >&2; exit 1 ;;
  esac
}

do_uninstall() {
  for p in "$ENGINE_HOME" \
           "$SKILLS/brainstem-ingest" "$SKILLS/brainstem-query" "$SKILLS/brainstem-synthesize" \
           "$BIN/brainstem" \
           "$CONFIG_HOME"; do
    if [ -e "$p" ]; then safe_rm "$p"; echo "removed  $p"
    else echo "skip     $p(不存在)"; fi
  done
  echo
  echo "brainstem 引擎已移除。腦資料未動。"
  echo "重裝:bash install.sh"
  echo "腦仍在,重指:brainstem use <你的腦目錄>"
  echo "若重測仍偵測到腦:檢查是否 export 了 \$BRAIN_DIR,或換到非腦目錄再開 session。"
}

case "${1:-}" in
  "")          : ;;            # 無參數 = 安裝(以下原有流程)
  --uninstall) do_uninstall; exit 0 ;;
  *)           echo "用法:install.sh [--uninstall]" >&2; exit 1 ;;
esac

OLD="$(cat "$ENGINE_HOME/VERSION" 2>/dev/null || echo none)"
```

- [ ] **Step 4: 在安裝迴圈上方加 drift 註解** —— 把現有這兩行(現 line 18-19,逐字):

```bash
# skills(真實檔、非 symlink)
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
```

改成(在中間插一行註解):

```bash
# skills(真實檔、非 symlink)
# ⚠ 新增 skill 時,此清單要同步四處:本迴圈 / install.sh do_uninstall / bin/test-install.sh / bin/test-uninstall.sh
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
```

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `bash bin/test-uninstall.sh`
Expected: PASS

- [ ] **Step 6: 回歸 —— 跑既有測試確認沒壞**

Run:
```bash
for t in test-find-brain test-config test-doctor test-init test-install test-skills-wiring test-ac4; do
  printf '%-22s ' "$t"; bash "bin/$t.sh" >/dev/null 2>&1 && echo PASS || echo FAIL
done
```
Expected: 全部 PASS(尤其 `test-install` —— 證明無參數安裝行為不變)。

- [ ] **Step 7: 手動冒煙 —— 真實環境 RED→GREEN 的最後確認(不污染真實安裝)**

Run:
```bash
T="$(mktemp -d)"; HOME="$T" XDG_DATA_HOME="$T/share" XDG_CONFIG_HOME="$T/config" bash install.sh >/dev/null
HOME="$T" XDG_DATA_HOME="$T/share" XDG_CONFIG_HOME="$T/config" bash install.sh --uninstall
rm -rf "$T"
```
Expected: 印出 6 行 `removed …` + 空行 + 4 行收尾訊息(腦資料未動 / 重裝 / 重指 / onboarding 自查)。

- [ ] **Step 8: Commit**

```bash
chmod +x bin/test-uninstall.sh
git add install.sh bin/test-uninstall.sh
git commit -m "feat(install): 加 --uninstall 移除引擎/skills/全域 config

不刪腦資料;safe_rm 白名單防呆;case \"\${1:-}\" 分派無參數安裝不變。
新增 bin/test-uninstall.sh(install→斷言在→uninstall→斷言全沒→idempotent)。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 文件(README + 專案 CLAUDE.md)

**Files:**
- Modify: `README.md`(升級段下方加「移除引擎」)
- Modify: `CLAUDE.md`(本機測試清單加 `test-uninstall.sh`;升級段提 `--uninstall`)

無測試(純文件,TDD 例外)。

- [ ] **Step 1: README 升級段加移除說明** —— 把現有(現 line 30-31):

```markdown
## 升級
重 clone + 重跑 `install.sh`;`brainstem --version` 看版號。
```

改成:

```markdown
## 升級 / 移除
重 clone + 重跑 `install.sh`;`brainstem --version` 看版號。
移除引擎:`bash install.sh --uninstall`(清 ENGINE_HOME / skills / 全域 config,**不刪腦資料**;重開 session 可乾淨重測 onboarding)。
```

- [ ] **Step 2: 專案 CLAUDE.md 測試清單加一行** —— 把現有(現 line 18-19):

```bash
bash bin/test-install.sh
bash bin/test-skills-wiring.sh
```

改成:

```bash
bash bin/test-install.sh
bash bin/test-uninstall.sh
bash bin/test-skills-wiring.sh
```

- [ ] **Step 3: 專案 CLAUDE.md 升級段提 `--uninstall`** —— 把現有(現 line 25-26):

```markdown
## 升級
重 clone 最新 repo + 重跑 `install.sh`(覆寫 ENGINE_HOME、bump VERSION)。`brainstem --version` 看裝了哪版。
```

改成:

```markdown
## 升級 / 移除
重 clone 最新 repo + 重跑 `install.sh`(覆寫 ENGINE_HOME、bump VERSION)。`brainstem --version` 看裝了哪版。
移除:`bash install.sh --uninstall`(清引擎/skills/全域 config,不刪腦)。
```

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: README/CLAUDE 補 install.sh --uninstall 與 test-uninstall

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 完成定義

- `bash bin/test-uninstall.sh` PASS;既有 7 測試全 PASS。
- `bash install.sh`(無參數)行為不變;`--uninstall` 清 4 路徑且 idempotent;未知參數 exit 1。
- 腦資料、`$SKILLS`/`$BIN` 共享父目錄未被刪。
- README / CLAUDE.md 反映新 flag 與新測試。
