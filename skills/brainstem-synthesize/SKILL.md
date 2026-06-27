---
name: brainstem-synthesize
description: 從你的知識圖譜(brain)的 notes/entities 合成文章草稿,落到 docs/drafts/。產帶 front-matter 與合成來源註解的草稿、補 log。Trigger:「產草稿」/「合成一篇」/「腦→草稿」。
---

# brainstem-synthesize — 從知識圖譜合成草稿

## 定位 brain(每次最先跑)
`$BRAIN` = 從 cwd 向上找到的腦根(含 `.brainroot` 的目錄):
```bash
BRAIN="$(d="$PWD"; while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done; [ -e "$d/.brainroot" ] && printf '%s' "$d")"
[ -z "$BRAIN" ] && { echo "找不到 .brainroot — 請先 cd 進你的 brain repo。"; exit 1; }
```

產出落點固定 `$BRAIN/docs/drafts/`。

## 前置(每次最先做)
1. 確認 `$BRAIN` 已定位(見上「定位 brain」);未定位則停止。
2. **lens 必讀**:`$BRAIN/lens.md` —— 口吻、角度、偏好以此為準。
3. **去重**:先掃 `$BRAIN/docs/drafts/` + 相關 `notes/`,確認此主題沒寫過;命中 → 停下問要不要更新,別重寫。

## 流程
1. **定來源**:接受「主題」或「指定 note/entity slugs」(優先後者)。給主題時優先選成熟度高的 note(evergreen > budding > seedling)。讀齊來源 notes + entity 全文;**排除 `sensitive: true`** 的 note。
2. **寫草稿** → `$BRAIN/docs/drafts/<slug>.md`(slug kebab-case、英文意譯優先;沿用既有 note slug、不另造同義詞)。front-matter **欄位固定**:
   ```yaml
   ---
   title: "…"
   date: <今天;向使用者要或用對話已知日期,不臆造>
   status: seedling
   tags: ["…"]
   summary: "…"
   locale: zh
   ---
   ```
   緊接一行 **HTML 合成來源註解**(草稿階段用這個):
   `<!-- 合成來源 notes: a, b ; entity: x ; source_kind=… -->`
   **不要**在草稿 front-matter 寫 `source_notes:` 欄 —— 草稿階段只用上面的 HTML 合成來源註解。
3. **內文規範**:用你 brain 的慣用語言撰寫。**不複述來源原文**(萃取觀點,不搬運句子);show, don't sell;語氣與立場一律以 `$BRAIN/lens.md` 為準。
4. **補 log**:`$BRAIN/log.md` append 一行 `YYYY-MM-DD synthesize — <來源> → docs/drafts/<slug>.md(待 review)`。
5. **體檢**:草稿在 `docs/drafts/`,**不進 wikilink 圖** → 不必跑 check.mjs;只有當你**同時動到** `notes/`/`entities/` 才跑 `bun "$BRAIN/check.mjs"` 確認 0 孤島/0 斷鏈。
6. **回報**:草稿路徑 + 「待 review」;**不自行 publish**。

## 規範
- 一篇一個角度;過雜就拆。
- 本 skill 到「草稿待 review」為止;publish/上站是使用者自己的下游,不在引擎範圍。
