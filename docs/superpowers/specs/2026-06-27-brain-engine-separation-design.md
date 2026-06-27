# 設計:引擎與腦分離(location-agnostic engine)

- 日期:2026-06-27
- 狀態:待 review
- 範圍:改引擎設計,適用所有使用者

## 問題

brainstem 被設計成**公開的引擎/範本**(MIT、README 主打「clone 下來養出第二大腦」、skills 全域安裝)。但「腦的內容」(`notes/`、`entities/`、`lens.md`、`log.md`、`docs/drafts/`)跟引擎放在**同一個 repo 根**。使用者(含引擎作者本人)一旦繼續餵料,私人想法就會跟著進這個準備公開的 repo。

根因:引擎 repo 根目錄同時放了 `.brainroot` + `lens.md` + seed `notes/`/`entities/`,所以它「身兼引擎與一顆腦」。而 `check.mjs` 把腦寫死成自己所在目錄,把腦永遠釘在引擎裡。

### 現況:三個元件對「腦在哪」解析不一致

| 元件 | 怎麼定位腦 | 綁引擎位置? |
|---|---|---|
| 3 個 skills | cwd 往上找 `.brainroot` | 否(已解耦) |
| `doctor.mjs` | `BRAIN_DIR` env ‖ 否則自己所在目錄 | 半(有 env 後門) |
| `check.mjs` | 寫死 `dirname(import.meta.url)` | 是(完全綁死) |
| `lens.md` / `.brainroot` / `notes/` | 引擎 repo 根 | 是 |

## 目標

引擎對「腦在哪」完全不關心。腦 = 任何含 `.brainroot` 的目錄(私有、版本控制在使用者自己手上)。引擎(skills + CLI)全域安裝,對任何腦運作。lens.md 跟著腦走,不釘在引擎 repo。

## 非目標(YAGNI)

- 不做引擎 repo 內的 demo 腦(已決議:只出 `_brain-template/`)。
- 不做腦的多 profile/多 lens 切換。
- 不碰 ingest/query/synthesize 的萃取邏輯,只碰它們「定位腦」的部分(其實已正確,無需改)。
- 不做 `brainstem` 以外的全域指令(如 publish)。

## 設計

### A. 統一「腦在哪」解析

新增共用 helper(例:`lib/find-brain.mjs`),語意與 skills 的 shell 片段一致:

1. 若 `BRAIN_DIR` 環境變數有設 → 用它(後門 / 測試用)。
2. 否則從 `process.cwd()` 往上走到 `/`,找第一個含 `.brainroot` 的目錄。
3. 找不到 → 丟出可讀錯誤:`找不到 .brainroot — 你不在任何腦裡。cd 進一顆,或先 brainstem init <dir>。` 並以 exit 1 結束。

`check.mjs`、`doctor.mjs` 都改用此 helper 取得 `BRAIN`:
- `check.mjs`:把第 10 行 `const BRAIN = dirname(fileURLToPath(import.meta.url))` 換成 helper。其餘 `join(BRAIN, ...)` 不變。
- `doctor.mjs`:把第 7 行 `process.env.BRAIN_DIR || dirname(...)` 換成 helper(helper 本身已含 BRAIN_DIR 邏輯)。
- skills 三個 SKILL.md 不變(已是 `.brainroot` 上行搜尋)。

### B. 引擎 repo 不再是一顆腦

從引擎 repo 根**移除**:`.brainroot`、`lens.md`、`log.md`、`notes/`(含 seed `atomic-note-one-idea.md`)、`entities/`(含 seed `brainstem.md`)。

移除後,在引擎 repo 根跑 `brainstem check` 會正確報「不在腦裡」——這是預期行為,不是 bug。

### C. `_brain-template/` —— 開新腦的骨架

新增 `_brain-template/`,內容為一顆**未設定**的新腦:

```
_brain-template/
  .brainroot
  CLAUDE.md                      # 腦版 onboarding 指引(見 E)
  lens.md                        # 含 <!-- LENS_UNCONFIGURED --> 的未設定範本(取 git HEAD:lens.md,非本 session 改過的工作版)
  log.md                         # 空(或一行表頭)
  .gitignore                     # 從現行 .gitignore 複製(.env / *.mp3 等)
  notes/
    .gitkeep
    atomic-note-one-idea.md      # 現行 seed note 移來
  entities/
    .gitkeep
    brainstem.md                 # 現行 seed entity 移來
  docs/
    drafts/.gitkeep
```

`init` 直接整包複製,lens 留未設定 → 第一次在新腦開 Claude Code 就由其 `CLAUDE.md` 觸發 onboarding。

### D. 全域 `brainstem` dispatcher

`install.sh` 除了 symlink skills,另在 `~/.local/bin/brainstem` 裝一個 dispatcher,**把引擎安裝路徑 baked-in**(與 skills symlink 用絕對路徑同模式):

```
brainstem check          # = bun <ENGINE>/check.mjs   (腦由 cwd 的 .brainroot 解析)
brainstem doctor         # = bun <ENGINE>/doctor.mjs
brainstem init <dir>     # 複製 <ENGINE>/_brain-template/ → <dir>
brainstem --dup <src>    # 透傳給 check.mjs 既有去重模式
```

- dispatcher 內容由 install.sh 在安裝時用實際 repo 絕對路徑產生(故引擎 repo 搬家後需重跑 install.sh,與 skills symlink 同樣的脆度,可接受)。
- `~/.local/bin` 不在 PATH 時,install.sh 印提示要使用者加入。
- `brainstem init <dir>`:`<dir>` 已含 `.brainroot` → 拒絕並提示;`<dir>` 不存在 → 建立;複製完印「下一步:cd <dir> 用 Claude Code 開啟,說 hi 走 onboarding」。

### E. 兩種 CLAUDE.md(角色分裂)

現行單一 CLAUDE.md 同時講「引擎結構」與「腦 onboarding」。拆成兩個角色:

- **`_brain-template/CLAUDE.md`(腦版,使用者實際會用的)**:從現行 CLAUDE.md 改寫——保留 onboarding 三步、原子筆記紀律、語言政策、lens 訪談;但
  - 移除「先跑 install.sh symlink skills」那段(引擎已全域裝好,腦不需再裝)。
  - 工具段改用全域 `brainstem check` / `brainstem doctor`(不再是 `bun run brain`)。
  - 第 0 步環境預檢改成 `brainstem doctor`。
- **引擎 repo 根 `CLAUDE.md`(引擎/貢獻者版)**:重寫成引擎架構說明——template/dispatcher/helper 結構、如何測試(`brainstem init /tmp/x && cd /tmp/x && brainstem check`)、不要把私人 notes commit 進引擎 repo 的警告。

### F. 文件

- `README.md`:安裝流程改為
  1. `git clone <repo> ~/brainstem-engine && cd ~/brainstem-engine && bash install.sh`(裝全域 skills + `brainstem` CLI)。
  2. `brainstem init ~/mybrain`(建議放在你私有的地方 / 私有 git remote)。
  3. `cd ~/mybrain`,用 Claude Code 開啟說 hi → onboarding。
  - 「結構」段標明:引擎 repo 出 `skills/`、`check.mjs`/`doctor.mjs`/`init.mjs`、`_brain-template/`;腦 repo 才有 `notes/`/`entities/`/`lens.md`。
- 引擎 repo 根 `.gitignore`:不再需要 ignore 腦內容(腦已不在此 repo);保留 `.env`/`.DS_Store`/`.superpowers/`。腦的 `.gitignore` 由 `_brain-template/.gitignore` 提供。

### G. 本 session 善後

本次 onboarding 把工作目錄的 `lens.md` 改成「已設定」版(移除了 sentinel)。實作時:`_brain-template/lens.md` 取 **git HEAD 的未設定版**(`git show HEAD:lens.md`),引擎根的 `lens.md` 隨 B 移除。淨效果是我這次的 lens 編輯被丟棄、不進任何 commit——符合「引擎 repo 不含設定過的 lens」。

## 影響的檔案

| 檔案 | 動作 |
|---|---|
| `lib/find-brain.mjs` | 新增(共用解析 helper) |
| `check.mjs` | 改用 helper 定位 BRAIN |
| `doctor.mjs` | 改用 helper;第 0 步措辭不變 |
| `init.mjs` | 新增(`brainstem init` 實作,複製 template) |
| `install.sh` | 加裝 `~/.local/bin/brainstem` dispatcher(baked 引擎路徑) |
| `_brain-template/**` | 新增(含現行 seed notes/entity、lens 範本、腦版 CLAUDE.md、.gitignore) |
| 根 `.brainroot`/`lens.md`/`log.md`/`notes/`/`entities/` | 移除(內容入 template) |
| 根 `CLAUDE.md` | 重寫為引擎/貢獻者版 |
| `README.md` | 改安裝流程與結構說明 |
| `package.json` | 移除 `brain`/`doctor` scripts(改由全域 `brainstem` 進入);保留供開發 |

## 測試 / 驗收

1. `bash install.sh` 後:`which brainstem` 有值;`ls ~/.claude/skills/brainstem-*` 三個 symlink 在。
2. `brainstem init /tmp/testbrain` → `/tmp/testbrain` 含 `.brainroot`/`lens.md`(未設定)/`CLAUDE.md`/seed notes。
3. `cd /tmp/testbrain && brainstem doctor` → 報「lens.md 尚未設定」(紅,符合預期);填 lens 後再跑 → 綠。
4. `cd /tmp/testbrain && brainstem check` → 對 `/tmp/testbrain` 的 notes 體檢(不是對引擎 repo)。
5. 在引擎 repo 根跑 `brainstem check` → 報「找不到 .brainroot — 你不在任何腦裡」,exit 1。
6. `brainstem init /tmp/testbrain`(已存在腦)→ 拒絕。
7. `BRAIN_DIR=/tmp/testbrain brainstem check`(在別處)→ 對 /tmp/testbrain 跑(後門生效)。
8. 引擎 repo `git status`:不含任何個人 note / 設定過的 lens。

## 風險 / 取捨

- **dispatcher 路徑脆**:引擎 repo 搬家後 `brainstem` 失效,需重跑 install.sh。與現行 skills symlink 同樣脆度,可接受;install.sh 印清楚的「搬家要重跑」提示。
- **`~/.local/bin` 未在 PATH**:install.sh 偵測並提示;不自動改使用者 shell rc。
- **兩個 CLAUDE.md 易漂移**:腦版與引擎版各自演進,onboarding 措辭可能不同步。緩解:腦版是唯一給使用者的真相,引擎版只談架構,職責不重疊。
- **既有使用者遷移**:若已有人把腦養在舊式「clone 即腦」結構裡,他們的 `.brainroot` 在 repo 根仍可用(helper 上行搜尋會找到),不會壞;只是建議他們改放私有處。README 加一段遷移說明(選填)。
