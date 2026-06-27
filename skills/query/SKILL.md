---
name: query
description: 問你的知識圖譜(brain)。從已累積的 notes/entities 回答問題、拉某主題的素材與連結,供思考與找寫作角度。唯讀不改圖。Trigger:「問 brain」/「brain 裡有沒有 X」/「找 X 的素材」。
---

# query — 查你的知識圖譜

## 定位 brain(每次最先跑)
`$BRAIN` = 從 cwd 向上找到的腦根(含 `.brainroot` 的目錄):
```bash
BRAIN="$(d="$PWD"; while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done; [ -e "$d/.brainroot" ] && printf '%s' "$d")"
[ -z "$BRAIN" ] && { echo "找不到 .brainroot — 請先 cd 進你的 brain repo。"; exit 1; }
```

## 前置
- 確認 `$BRAIN` 已定位(見上「定位 brain」);未定位則停止。
- **唯讀**:本 skill 不建/不改任何頁(要建頁用 ingest)。

## 流程
先讀 `$BRAIN/lens.md`,讓「該浮什麼」朝使用者判準偏。
1. 解析問題的關鍵概念/entity。
2. 在 `$BRAIN/notes/`、`$BRAIN/entities/`、`$BRAIN/_index.md` 用 grep/Glob + 讀檔找命中。
3. 沿 `[[wikilink]]` 與 `related` 欄展開一兩跳鄰居,聚出相關子圖。
4. **過濾**:預設排除 `sensitive: true` 的 note;僅當呼叫方明確要求內部/私有查詢時才納入。
5. 回答 + 附「相關 note 清單」(每筆:title · status · 路徑)。

## 規範
- 答案以圖裡實際內容為據,grep 到再講,**不臆造**。
- 用你 brain 的慣用語言回答。
