# 設計:可設定的 synthesize 草稿落點(global `draftsDir`)

- 日期:2026-06-27
- 狀態:待 review
- 範圍:在既有「引擎與腦分離」之上,加一個全域可設定的草稿輸出目錄
- 前置:`docs/superpowers/specs/2026-06-27-brain-engine-separation-design.md`(已實作於分支 `design/brain-engine-separation`)

## 問題

synthesize 產出的草稿落點目前**寫死**為 `$BRAIN/docs/drafts/`(相對於解析到的腦),無法獨立指定。使用者常想把草稿直接導向腦以外的地方(例如網站 / 部落格 repo 的 content 目錄),目前做不到——草稿只能跟著腦走。

硬編點有二:
- `skills/brainstem-synthesize/SKILL.md`:落點(:24)、去重掃描(:20)、log 行文字(:39)、描述(:3/:15)都用 `$BRAIN/docs/drafts/`。
- `check.mjs:72`:體檢數草稿時 `join(BRAIN, "docs/drafts")`。

全域 config(`config.json`)目前只有 `brain` 一個 key。

## 目標

新增一個**全域**、**可選**的 `draftsDir`,讓草稿輸出目錄可被指定到任意絕對路徑,並保持「未設定 = 跟今天完全一樣」的向後相容。沿用既有腦指標那套 CLI / config 機制,維持一致。

## 非目標(YAGNI)

- 不做每顆腦各自的 drafts 設定(已決議走全域單一 `draftsDir`)。
- 不改草稿的**內容 / front-matter 格式**(只改「寫去哪」,不改「寫什麼」)。
- 不搬動 `log.md`——log 是腦的狀態,永遠留在 `$BRAIN/log.md`(只有 log 內記錄的「草稿路徑文字」跟著 `draftsDir` 走)。
- 不讓 `use`/`init` 去動 `draftsDir`(只印提醒,見 E)。
- install.sh 不改(新 lib + 更新後的 dispatcher/config 本來就整包複製)。

## 決策(brainstorming 已定)

- **全域 `draftsDir`**:一個值,獨立於哪顆腦。**未設 = 跟著作用中的腦**(`$BRAIN/docs/drafts`);**設了 = 釘在該絕對路徑**,不隨腦切換。這同時給了「跟著腦」與「釘外部」兩種行為。
- **CLI**:`brainstem drafts`(印)/ `brainstem drafts <dir>`(設)/ `brainstem drafts --default`(清回預設)。
- **set 時**:目錄不存在就 `mkdir -p` 建好(drafts 是輸出夾,不要求 `.brainroot`)。
- **`where` 不變**:只印腦(維持 `BRAIN="$(brainstem where)"` 的單值契約)。兩個路徑都要看 → `brainstem doctor`。
- **`use`/`init`**:只動腦指標;`draftsDir` 被 pin 時印一行提醒。

## 設計

### A. 解析 `resolveDrafts()`

新增 `lib/drafts.mjs`,匯出 `resolveDrafts()`:

1. 讀全域 config(`configPath()` from `find-brain.mjs`);若有 `draftsDir` → 回它(絕對路徑,**不需要腦也成立**)。
2. 否則 → `join(findBrain(), "docs/drafts")`;`findBrain()` 為 null → 丟錯(stderr + exit 1,訊息同 where 風格)。

直跑(`import.meta.main`)= `brainstem drafts`:印解析結果到 stdout、錯誤到 stderr + exit 1。與 `find-brain.mjs` 同形(可 import、可直跑)。

**刻意不驗 `draftsDir`**:不像腦指標在讀取時驗 `.brainroot`(find-brain 第 3 級),`draftsDir` 是純輸出夾、無對應標記,讀取時**採信不驗**;存在性由 set 的 `mkdir -p` 與 synthesize 寫入前的 `mkdir -p` 保證。

### B. config 讀寫 `set-drafts` / `unset-drafts`

`lib/config.mjs` 擴充(現有 `setBrain` / CLI `set <dir>` 不變):

- `setDrafts(dir)`:`resolve` 絕對路徑 → `mkdir -p`(連同 config 目錄)→ 把 `draftsDir` 寫進 `config.json`(與既有 `brain` key 並存,不互相覆蓋)。**不要求 `.brainroot`**。
- `unsetDrafts()`:讀 config、刪掉 `draftsDir` key、重寫(`brain` 保留)。key 本就不存在也安靜成功(idempotent)。
- CLI 入口擴充:`set <dir>`(腦,原樣)、`set-drafts <dir>`、`unset-drafts`。

config.json 結構由 `{ "brain": "<abs>" }` 變為 `{ "brain": "<abs>", "draftsDir": "<abs>" }`(`draftsDir` 可缺)。寫入時保留另一個 key(read-merge-write,不要整檔覆蓋掉 `brain`)。

### C. dispatcher `drafts` 子命令 + 多行 `--help`

`bin/brainstem` 加 `drafts` 分派(純 shell,依參數分流):

```bash
drafts)
  if [ "$#" -eq 0 ]; then exec bun "$ENGINE_HOME/lib/drafts.mjs"
  elif [ "$1" = "--default" ]; then exec bun "$ENGINE_HOME/lib/config.mjs" unset-drafts
  else exec bun "$ENGINE_HOME/lib/config.mjs" set-drafts "$1"; fi ;;
```

`--help` / 無參數的用法字串由單行升級為**多行**(一命令一行),涵蓋:`where`、`use <dir>`、`init <dir>`、`check [--dup <src>]`、`doctor`、`drafts [<dir> | --default]`、`--version`。

### D. 消費端改用解析後的 drafts

- `skills/brainstem-synthesize/SKILL.md`:在定位段之後加 `DRAFTS="$(brainstem drafts)"`;把落點(:24)、去重掃描(:20)、log 行記錄的草稿路徑(:39)由 `$BRAIN/docs/drafts/` 改為 `$DRAFTS/`。描述行(:3/:15)措辭改為「落到設定的 drafts 目錄(預設 `$BRAIN/docs/drafts/`)」。`log.md` 本身仍 append 到 `$BRAIN/log.md`(不變)。
- `check.mjs:72`:草稿計數由 `join(BRAIN,"docs/drafts")` 改為 `resolveDrafts()`(import 自 `./lib/drafts.mjs`)。外接 drafts 時體檢數字才一致;目錄不存在仍視為 0(維持現有的 `existsSync` 防呆)。

### E. doctor 顯示 + use/init 提醒

- `doctor.mjs`:在 brain 行附近加一行 info,印 `resolveDrafts()` 結果,並標示是「pinned <path>」還是「預設(跟腦)」。讓「兩個路徑都看 doctor」成立。
- `lib/config.mjs setBrain(dir)` 與 `init.mjs`:設好腦後,若 config 內 `draftsDir` 已設,印一行提醒(stdout):`注意:drafts 固定在 <path>,不隨腦切換;brainstem drafts --default 可改回跟著腦`。只印不動。

### F. 文件

`_brain-template/CLAUDE.md` 工具段、引擎 `CLAUDE.md`(本機測試/CLI 段)、`README.md` 常用段,各補 `brainstem drafts [<dir> | --default]` 一行用法 + 一句「未設 = 落在 `$BRAIN/docs/drafts`」。

### G. install / 升級

install.sh 不改(`lib/drafts.mjs`、更新後的 `lib/config.mjs` / `bin/brainstem` / `check.mjs` / `doctor.mjs` 都在既有複製清單內)。改完**重跑 `install.sh`** 升級全域。

## 影響的檔案

| 檔案 | 動作 |
|---|---|
| `lib/drafts.mjs` | 新增(`resolveDrafts()` + 直跑 = `brainstem drafts`) |
| `lib/config.mjs` | 加 `setDrafts`/`unsetDrafts` + CLI `set-drafts`/`unset-drafts`;`setBrain` 加 pinned 提醒 |
| `bin/brainstem` | 加 `drafts` 分派;`--help` 升級多行 |
| `check.mjs` | 草稿計數改用 `resolveDrafts()` |
| `doctor.mjs` | 加印 resolved drafts(pinned/預設) |
| `init.mjs` | pinned 時加提醒 |
| `skills/brainstem-synthesize/SKILL.md` | 落點/去重/log 路徑改 `$DRAFTS`;描述措辭 |
| `_brain-template/CLAUDE.md`、`CLAUDE.md`、`README.md` | 補 `brainstem drafts` 用法 |
| `bin/test-drafts.sh` | 新增 |

## 測試 / 驗收(`bin/test-drafts.sh`,bash、PASS/FAIL、非零退出)

1. **未設 = 跟腦**:`BRAIN_DIR=$B` 下 `bun lib/drafts.mjs` → 印 `$B/docs/drafts`。
2. **set**:`config.mjs set-drafts $D`(`$D` 不存在)→ `$D` 被 `mkdir -p` 建好;`config.json` 同時含 `brain`(若先前有)與 `draftsDir`;`resolveDrafts()` 回 `$D`,**即使換 BRAIN_DIR 也仍回 `$D`**(獨立於腦)。
3. **set 不毀 brain**:先 `set $B`(腦)再 `set-drafts $D`,config 兩個 key 都在;反序亦然。
4. **unset**:`config.mjs unset-drafts` → `draftsDir` key 消失、`brain` 保留;`resolveDrafts()` 回 `$BRAIN/docs/drafts`。
5. **pinned 獨立於腦且免腦**:`draftsDir` 設好後,在無 `.brainroot`、無 `BRAIN_DIR` 的 cwd 跑 `bun lib/drafts.mjs` → 仍回 `$D`(不報「找不到腦」)。
6. **未設且無腦**:無 `draftsDir`、無腦 → `bun lib/drafts.mjs` 報錯 stderr + exit 1。
7. **dispatcher 分流**(若環境可裝):`brainstem drafts` / `brainstem drafts <dir>` / `brainstem drafts --default` 三路各自正確。
8. **check 一致**:`draftsDir` 指到含 N 個 `.md` 的外部夾 → `brainstem check` 的草稿數 = N。
9. **提醒**:`draftsDir` 已 pin 時,`init`(或 `config.mjs set` 腦)輸出含「不隨腦切換」字樣;未 pin 時不印。
10. **回歸**:既有 `bin/test-*.sh` 全綠(尤其 `test-config.sh`、`test-doctor.sh`、`test-init.sh` 不因 config 多一個 key 而壞)。

## 風險 / 取捨

- **pinned 的隱形性**:草稿釘在外部夾後,切腦不會搬;靠 `use`/`init`/`doctor` 的提醒緩解(E)。
- **config 多 key 的寫入**:`set-drafts`/`unset-drafts` 必須 read-merge-write,不可整檔覆蓋(否則洗掉 `brain`)。已列為測試 3/4 的重點。
- **`draftsDir` 路徑失效**(被刪/搬走):`resolveDrafts()` 只回字串;synthesize 寫入前確保夾在(set 時已 `mkdir -p`;若使用者事後刪了,寫入步驟需自行 `mkdir -p`——列入 synthesize skill 的寫檔步驟)。
- **與既有 spec 的關係**:這是純加法,不改腦解析優先序、不改 install 模型,風險侷限在 synthesize 與 check 的 drafts 路徑。

## 決策紀錄

- 全域 `draftsDir`(非每腦):與目前單一預設腦一致、最簡;「未設=跟腦 / 設=釘住」一個 key 給兩種行為。
- `where` 不擴充成印兩個:保 `$(brainstem where)` 單值契約;雙路徑歸 `doctor`。
- `use`/`init` 不動 drafts、只提醒:保持單一職責,避免靜默搬掉使用者刻意設的外部落點。
