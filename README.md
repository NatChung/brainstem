# brainstem

> A Claude-Code-native engine for growing your own knowledge graph — a second brain that learns to think like you.
> 一個 Claude Code 原生的知識圖譜引擎:clone 下來,養出一個照你思考方式生長的第二大腦。

## 它跟 NotebookLM / RAG 差在哪(兩個差異化)
1. **餵入即連結** — 每則素材在「餵入當下」就被萃取成原子 note 並建立 `[[連結]]`,圖的拓樸是你的聯想結構,不是查詢時才算的相似度。
2. **lens** — 一個 `lens.md` 寫「你怎麼判斷」,收料與生成都朝你的判準偏。

## 安裝
1. `git clone <repo> ~/your-brain && cd ~/your-brain`
2. 用 Claude Code 從這個資料夾開啟,直接說「hi」。
3. 它讀 `CLAUDE.md` 帶你走 onboarding:全域裝 skills(可加前綴)→ 填 `lens.md` → 餵第一個來源 → `bun run brain` 綠燈。

需求:[Bun](https://bun.sh)(跑 `check.mjs`)、Claude Code。

## Quickstart:餵第一個來源
- 貼一段想法,或給一個文章 URL,跟 Claude 說「ingest 這個」。
- 進階(選用):YouTube 無字幕影片可下音檔用 whisper 轉錄再餵(需 `yt-dlp` + 平台對應 whisper)。

## 結構
- `notes/` 原子筆記(`[[wikilink]]` 互連)· `entities/` 人/組織/產品/工具
- `lens.md` 你的判準 · `docs/drafts/` 合成草稿 · `check.mjs` 體檢/去重
- skills:`ingest` / `query` / `synthesize`

## License
MIT
