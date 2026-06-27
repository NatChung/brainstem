# brainstem — 你的知識圖譜引擎(Claude Code 自動載入)

> A Claude-Code-native engine for growing a personal knowledge graph ("second brain").
> 中文為主、英文輔助。

這個 repo 本身就是一個「腦」:`notes/` 原子筆記彼此 `[[wikilink]]`、`entities/` 放人/組織/產品/工具、`docs/drafts/` 放合成草稿。`check.mjs` 是體檢/去重工具。

## 定位 brain
`$BRAIN` = 從 cwd 向上找到、含 `.brainroot` 的目錄:
```bash
BRAIN="$(d="$PWD"; while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done; [ -e "$d/.brainroot" ] && printf '%s' "$d")"
```

## 首次設定(對話式 onboarding)
**每次 session 載入都先讀根目錄 `lens.md`**——若仍含 `<!-- LENS_UNCONFIGURED -->`,在執行使用者任何請求之前先跑以下 onboarding。

skills 已在 repo 內、**開 repo 即可用**(`/brainstem-ingest`·`/brainstem-query`·`/brainstem-synthesize`),**不必安裝**。你的 note 存在這個 repo 的 `./notes/`、entities 在 `./entities/`。

**先看有沒有既有圖**:若 `./notes/` 已有**非 seed** 的 `.md`(seed = 僅 `atomic-note-one-idea.md` + `brainstem.md`)→ 印「找到既有 N 則 note,沿用這個腦、不重建」,跳過第 2 步的「建第一則」概念、直接確認 lens(若 sentinel 仍在才走第 1 步訪談)→ 第 3 步體檢。否則走完整三步:

1. **填 lens**——lens 改變三件事:**ingest 收料**抽什麼/留什麼、**query 查**時先浮什麼、**synthesize 寫**時什麼口吻。三題各對一件,**每題給範例 + 一條【推薦】,不知道就用推薦的**:
   - **(收料)什麼該留、什麼是雜訊?** 例:留可操作判準丟鋪陳 · 留反直覺丟常識 · **【推薦】先都留,之後再篩**
   - **(查)回來問時最想先看到什麼?** **【推薦】先給結論 + 關鍵 note** · 先給反方/不同角度 · 先給原始出處
   - **(寫)要像誰在說話?** **【推薦】第一人稱、直白、不誇大** · 條列極簡 · 像教學帶例子

   出口三選一:挑範例 / 說「**用推薦的**」(整步可「**全用推薦**」一句帶過)/ 說「**我貼 lens**」貼現成的。把回答寫進 `lens.md` 對應三段(收料時 / 查時 / 寫時),**移除 `<!-- LENS_UNCONFIGURED -->` 那行**。「全用推薦」= 三段各寫:收料「先都留,之後再篩」/ 查「先給結論 + 幾個關鍵 note」/ 寫「第一人稱、直白、不誇大」。
2. **餵第一個來源**:用 `brainstem-ingest` 餵一個 URL 或一段貼上的想法,建第一則 note。
3. **體檢**:`bun run brain`,確認 0 孤島 / 0 斷鏈。

> 進階:想在**別的 repo** 也能呼叫這顆腦 → 跑 `bash install.sh`(全域裝 `~/.claude/skills/brainstem-*`,**需重開 session**)。先前裝過(任何舊版/前綴)的全域 symlink 在 skill 改名後會斷,重跑一次 `install.sh` 即可。本 repo 內不需要。

## 原子筆記紀律
- 一則 note 一個想法;過長就拆。
- 連結在 ingest 當下就建(非查詢時)——這是跟 RAG 的根本差別。
- 萃取「理解被校準後的那一兩句」+ 最可操作的判準,不搬運原文。
- seed 的 `atomic-note-one-idea` / `brainstem` 兩頁是示範,看懂後可刪。

## 工具
- `bun run brain` — 體檢(規模/成熟度/圖健康/sensitive/log 大小);`bun run brain --dup <來源>` 去重。
- `bun run doctor` — 環境體檢(`.brainroot` / `lens.md` 是否設定 / `yt-dlp`·whisper 提示),紅項缺 → exit 1。
- 三個 skill:`brainstem-ingest`(餵料)/`brainstem-query`(查)/`brainstem-synthesize`(產草稿)。

## 語言政策
- CLAUDE.md 本身與 skill 指令用中文撰寫。
- 使用者的 notes / lens 語言由使用者自訂——英文、中文或混用均可,無強制。
