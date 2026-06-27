# brainstem uninstall — 設計

> `bash install.sh --uninstall`:一鍵移除 brainstem 引擎(CLI + skills + 全域設定),供重開 session 重測 onboarding。**絕不刪使用者腦資料。**

## 目標 / 非目標

- **目標**:把 `install.sh` 裝過的東西 + 全域 config 全清掉,讓環境回到「未安裝」狀態,可反覆執行。
- **非目標**:不刪任何腦(`.brainroot` 目錄 / notes / entities / drafts);不做 `--purge` 之類分級(YAGNI);不動 `brainstem` CLI 的子指令集。

## 放置:`install.sh --uninstall`

放進 `install.sh`(非 `bin/brainstem`)。理由:與安裝對稱、即使 dispatcher 已壞/已刪也能跑、避免 CLI 自刪自己。`brainstem` CLI 維持只管腦操作(where/use/init/check/doctor/drafts),不加 uninstall 子指令。

### 參數分支(逐字)

`install.sh` 目前 `set -euo pipefail` 且**完全不引用位置參數**;直接加 `case "$1"` 會在無參數呼叫時因 `set -u` 觸發 unbound variable。必須用:

```bash
case "${1:-}" in
  "")          : ;;            # 無參數 = 安裝(現有行為,不變)
  --uninstall) do_uninstall; exit 0 ;;
  *)           echo "用法:install.sh [--uninstall]" >&2; exit 1 ;;
esac
```

- `""` 分支落回現有安裝流程。
- `*`(未知參數)報錯 exit 1。現有呼叫者一律無參數,相容。

### 路徑常數同源(防 drift)

`ENGINE_HOME` / `SKILLS` / `BIN` 三個常數(現在 install.sh line 6-8)**定義位置前移到參數分支之前**,安裝與移除共用同一份,且一律從 env 即時計算:

```bash
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/brainstem"
```

因為全部從 env 算,`test-uninstall.sh` 用 `HOME`/`XDG_*` override 到 TMP 時自動生效,不會與真實 HOME 行為 drift。

## 移除清單(idempotent,逐項印出)

| 目標 | 路徑 | 說明 |
|---|---|---|
| 引擎 | `$ENGINE_HOME` | 整個 `~/.local/share/brainstem`(check/doctor/init.mjs、lib、_brain-template、VERSION) |
| skills | `$SKILLS/brainstem-{ingest,query,synthesize}` | 三個 skill 子目錄(**不刪** `$SKILLS` 父目錄,可能被別工具共用) |
| CLI | `$BIN/brainstem` | dispatcher 單檔(**不刪** `$BIN` 父目錄) |
| 全域設定 | `$CONFIG_HOME` | 整個 `~/.config/brainstem`(含 `config.json` = 腦指標 + draftsDir) |

- **一律用 `rm -rf`**(目錄與單檔皆可,含 `$BIN/brainstem` 單檔):對不存在路徑回 0,與 `set -e` 相容,故可反覆執行、第二次仍 exit 0。
- **skill 清單 drift**:`brainstem-{ingest,query,synthesize}` 此清單已硬編在 `install.sh`(安裝迴圈)與 `test-install.sh`;uninstall + test-uninstall 會成第三、四處。本輪沿用硬編,但在 `install.sh` 該迴圈上方加註解:「**新增 skill 時,install / uninstall / test-install / test-uninstall 四處清單同步**」。

### 刪除前防呆

每個刪除目標在 `rm` 前斷言**路徑非空且結尾符合預期後綴**,作為廉價保險(防 env 異常導致 `$ENGINE_HOME` 解析成 `/` 之類):

```bash
safe_rm() {  # $1 = 路徑;結尾須含 brainstem 字樣才刪
  case "$1" in
    */brainstem|*/brainstem-ingest|*/brainstem-query|*/brainstem-synthesize) rm -rf "$1" ;;
    *) echo "防呆:拒刪非預期路徑 $1" >&2; exit 1 ;;
  esac
}
```

`$BIN/brainstem` 結尾為 `/brainstem`、`$ENGINE_HOME`/`$CONFIG_HOME` 同；三個 skill 結尾為 `/brainstem-*`,全部通過白名單。

**防護邊界(明載,免後續維護者誤信)**:此白名單**只驗後綴、不驗前綴**。它擋得住「結尾完全不像 brainstem」的離譜值(如 env 異常使路徑變 `/` → 不匹配 → exit 1),但**擋不住「結尾像、前綴是錯目錄」**(如 `XDG_DATA_HOME` 被設成某重要目錄時的 `<那目錄>/brainstem`)。因 `safe_rm` 的輸入永遠是受控的 4 條固定路徑、不接外部輸入,實務風險低;此防呆定位是「擋離譜空值」,**非**「擋使用者把 XDG 指到錯地方」。

### `do_uninstall` 函式(逐字,收尾訊息單一來源)

```bash
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
```

- `[ -e "$p" ]` 守衛只為輸出區分 `removed` vs `skip(不存在)`(對應第二次 idempotent 跑);不影響安全(刪仍走 `safe_rm` 白名單)。
- skill 三項清單在此為第三處硬編(install 迴圈、test-install、此處、test-uninstall 共四處),受 §移除清單的 drift 註解約束。

## 安全 / 使用者須知

- **只刪上述固定引擎路徑,不碰腦資料。**
- **收尾 4 行訊息由 `do_uninstall` 單一來源印出**(見上):腦資料未動 / 重裝指令 / 重指腦指令 / onboarding 自查提示。
- **不做互動確認**:此功能用於反覆重測,prompt 礙事;移除可逆(重跑 install)。

### ⚠️ 觸發 onboarding 的前提(對照 `lib/find-brain.mjs`)

`findBrain()` 解析序為 **① `BRAIN_DIR` 環境變數 → ② cwd 上行找 `.brainroot` → ③ 全域 config**。**刪 config 只清掉 ③**。因此「移除後重測會落到『無腦 → onboarding/init』」**只在以下兩前提同時成立時為真**:

1. shell **未** export `BRAIN_DIR`,且
2. 重測時 cwd **不在**任何含 `.brainroot` 的腦目錄內。

否則 `findBrain()` 仍會回傳一顆腦、onboarding 不觸發。**uninstall 結尾須多印一行提示**:

> `若重測仍偵測到腦:檢查是否 export 了 $BRAIN_DIR,或換到非腦目錄再開 session。`

避免使用者照做卻測不到 onboarding、誤判功能壞掉。

### 移除後 `brainstem` 指令的行為

dispatcher 被刪後 `brainstem` 直接 command-not-found(即使殘留,`$ENGINE_HOME/lib/*` 也沒了會 crash)。**這是預期行為**——spec 明載「移除後 brainstem 指令即不可用,重裝才回來」。`doctor.mjs` 等引擎檔本身不需改動。

## 測試:`bin/test-uninstall.sh`

沿用 `test-install.sh` 的隔離手法(`HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` → TMP,`trap rm -rf EXIT`):

1. `bash install.sh`(裝)。
2. 斷言四類目標**都在**:`$ENGINE_HOME/VERSION`、三個 `$SKILLS/brainstem-*/SKILL.md`、`$BIN/brainstem`。
3. 手動塞一個 `$XDG_CONFIG_HOME/brainstem/config.json`(install 不會產生它),模擬「已設過腦」。
4. `bash install.sh --uninstall`。
5. 斷言四類目標**全不存在**:`$ENGINE_HOME` 目錄、三個 skill 目錄、`$BIN/brainstem`、`$XDG_CONFIG_HOME/brainstem` **整個目錄**(不只 config.json)。
6. 再跑一次 `bash install.sh --uninstall` → 仍 **exit 0**(idempotent)。
7. `echo PASS`。

並把 `bash bin/test-uninstall.sh` 加進專案 `CLAUDE.md` 的「本機測試」清單。

## 文件

- `README.md` 安裝段補一行:`移除引擎:bash install.sh --uninstall(不刪腦資料)`。
- 專案 `CLAUDE.md`:測試清單加 `test-uninstall.sh`;升級段附近提一行此 flag。

## 實作順序(TDD)

1. 先寫 `bin/test-uninstall.sh`(RED:`install.sh` 現在不引用 `$1`,`--uninstall` 會被**忽略而照裝**;故移除後斷言「目標全不存在」會 FAIL——目標其實還在/被重裝)。
2. 改 `install.sh`:前移路徑常數、加 `case "${1:-}"` 分支、`do_uninstall`(含 `safe_rm` 防呆與結尾提示)。
3. GREEN:`test-uninstall.sh` 過;回歸跑 `test-install.sh` 等全套 7+1 測試。
4. 補 README / CLAUDE.md。
