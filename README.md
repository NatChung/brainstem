# brainstem

> A Claude-Code-native engine for growing your own knowledge graph — a second brain that learns to think like you.
> 一個 Claude Code 原生的知識圖譜引擎:clone 下來,養出一個照你思考方式生長的第二大腦。

## 它跟 NotebookLM / RAG 差在哪(兩個差異化)
1. **餵入即連結** — 每則素材在「餵入當下」就被萃取成原子 note 並建立 `[[連結]]`,圖的拓樸是你的聯想結構,不是查詢時才算的相似度。
2. **lens** — 一個 `lens.md` 寫「你怎麼判斷」,收料與生成都朝你的判準偏。

## 安裝
1. `git clone <repo> ~/your-brain && cd ~/your-brain`
2. 用 Claude Code 從這個資料夾開啟,直接說「hi」。
3. 它讀 `CLAUDE.md` 帶你走 onboarding:**填 `lens.md` → 餵第一個來源 → `bun run brain` 綠燈**。skills 開 repo 即用,免裝。

需求:[Bun](https://bun.sh)、Claude Code。先跑 `bun run doctor` 檢查環境就緒。

## Quickstart:餵第一個來源
- 貼一段想法、給一個文章 **URL**,或一支 **YouTube 影片**——跟 Claude 說「ingest 這個」。
- YouTube:**有字幕**的影片 `yt-dlp` 直接抓字幕(輕、快、最常見)。**無字幕**才需轉錄——`yt-dlp` 下音檔 → whisper 轉文字(**yt-dlp 和 whisper 是兩個不同工具**);whisper **依你的 OS**(Mac=`mlx-whisper`、Win/Linux=`faster-whisper`),屬進階。

## 結構
- `notes/` 原子筆記(`[[wikilink]]` 互連)· `entities/` 人/組織/產品/工具
- `lens.md` 你的判準 · `docs/drafts/` 合成草稿 · `check.mjs` 體檢/去重
- skills:`brainstem-ingest` / `brainstem-query` / `brainstem-synthesize`

## License
MIT
