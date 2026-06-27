---
name: brainstem-query
description: 問你的知識圖譜(brain)。從已累積的 notes/entities 回答問題、拉某主題的素材與連結,供思考與找寫作角度。唯讀不改圖。Trigger:「問 brain」/「brain 裡有沒有 X」/「找 X 的素材」。
---

# brainstem-query — 查你的知識圖譜

## 定位 brain(每次最先跑)
`$BRAIN` 由全域 `brainstem` 解析(BRAIN_DIR → cwd 的 `.brainroot` → 全域指標):
```bash
command -v brainstem >/dev/null || { echo "找不到 brainstem 指令 — 把 ~/.local/bin 加進 PATH 或重跑 install.sh。" >&2; exit 1; }
BRAIN="$(brainstem where)" || exit 1   # where 失敗訊息已走 stderr
```

- 被問「我腦在哪 / 怎麼換腦」時:跑 `brainstem where` 回答位置;要換預設腦引導 `brainstem use <dir>`(不替使用者擅自改)。

## 前置
- 確認 `$BRAIN` 已定位(見上「定位 brain」);未定位則停止。
- **唯讀**:本 skill 不建/不改任何頁(要建頁用 brainstem-ingest)。

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
