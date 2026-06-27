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
未設定判準:根 `lens.md` 仍含 `<!-- LENS_UNCONFIGURED -->`。

skills 已在 repo 內、**開 repo 即可用**(`/ingest`·`/query`·`/synthesize`),**不必安裝**。三步:

1. **填 lens**:訪談使用者,**用具體情境提問、不要用術語當題目**。三組各問一題:
   - 我怎麼判斷:「讀一篇文章 / 看一個新工具時,什麼會讓你**信它 / 不信它**?」
   - 我的偏好:「你希望這顆腦幫你**留下什麼**——哪種素材對你最有用?」
   - 語氣:「產出的文章該**像誰在說話**?有沒有不准用的詞 / 一定要的口吻?」
   每組都附 escape-hatch:「**或直接說『我貼 lens』**,把你寫好的判準貼上來,跳過訪談。」
   把回答寫進 `lens.md`,並**移除 `<!-- LENS_UNCONFIGURED -->` 那行**。
2. **餵第一個來源**:用 `ingest` skill 餵一個 URL 或一段貼上的想法,建第一則 note。
3. **體檢**:`bun run brain`,確認 0 孤島 / 0 斷鏈。

> 進階:想在**別的 repo** 也能呼叫這顆腦 → 跑 `bash install.sh`(全域裝進 `~/.claude/skills/`,**需重開 session** 才生效)。本 repo 內不需要。

## 原子筆記紀律
- 一則 note 一個想法;過長就拆。
- 連結在 ingest 當下就建(非查詢時)——這是跟 RAG 的根本差別。
- 萃取「理解被校準後的那一兩句」+ 最可操作的判準,不搬運原文。
- seed 的 `atomic-note-one-idea` / `brainstem` 兩頁是示範,看懂後可刪。

## 工具
- `bun run brain` — 體檢(規模/成熟度/圖健康/sensitive/log 大小);`bun run brain --dup <來源>` 去重。
- `bun run doctor` — 環境體檢(`.brainroot` / `lens.md` 是否設定 / `yt-dlp`·whisper 提示),紅項缺 → exit 1。
- 三個 skill:`ingest`(餵料)/`query`(查)/`synthesize`(產草稿)。

## 語言政策
- CLAUDE.md 本身與 skill 指令用中文撰寫。
- 使用者的 notes / lens 語言由使用者自訂——英文、中文或混用均可,無強制。
