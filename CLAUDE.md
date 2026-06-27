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
**當使用者打招呼或說要開始,且偵測到「未設定」就主動帶他走**——
未設定的判準:根 `lens.md` 仍含 `<!-- LENS_UNCONFIGURED -->`。
步驟:
1. **裝 skills(全域)**:問使用者要不要把 `skills/*` symlink 進 `~/.claude/skills/`,以及要不要加前綴(預設無;要同機跑多顆腦或測試就加,例 `test` → `test-ingest`)。執行 `bash install.sh [前綴]`。
2. **填 lens**:打開 `lens.md`,訪談使用者「你怎麼判斷、偏好什麼、語氣」,寫進去並**移除 `<!-- LENS_UNCONFIGURED -->` 那行**。
3. **餵第一個來源**:用 `ingest` skill 餵一個 URL 或一段貼上的想法,建第一則 note。
4. **體檢**:`bun run brain`,確認 0 孤島 / 0 斷鏈。

## 原子筆記紀律
- 一則 note 一個想法;過長就拆。
- 連結在 ingest 當下就建(非查詢時)——這是跟 RAG 的根本差別。
- 萃取「理解被校準後的那一兩句」+ 最可操作的判準,不搬運原文。
- seed 的 `atomic-note-one-idea` / `brainstem` 兩頁是示範,看懂後可刪。

## 工具
- `bun run brain` — 體檢(規模/成熟度/圖健康/sensitive/log 大小);`bun run brain --dup <來源>` 去重。
- 三個 skill:`ingest`(餵料)/`query`(查)/`synthesize`(產草稿)。

## 語言政策
- CLAUDE.md 本身與 skill 指令用中文撰寫。
- 使用者的 notes / lens 語言由使用者自訂——英文、中文或混用均可,無強制。
