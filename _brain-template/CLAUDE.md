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
