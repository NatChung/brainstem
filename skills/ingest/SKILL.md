---
name: ingest
description: 把來源餵進你的知識圖譜(brain)。讀來源(URL / 貼進的想法 / 檔案),抽原子概念 + entities,建/更新互連的 markdown note 頁、cross-reference、補 index、寫 log。Trigger:「餵進 brain」/「ingest 這個」/「記進第二大腦」。
---

# ingest — 餵料進你的知識圖譜

## 定位 brain(每次最先跑)
`$BRAIN` = 從 cwd 向上找到的腦根(含 `.brainroot` 的目錄):
```bash
BRAIN="$(d="$PWD"; while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done; [ -e "$d/.brainroot" ] && printf '%s' "$d")"
[ -z "$BRAIN" ] && { echo "找不到 .brainroot — 請先 cd 進你的 brain repo。"; exit 1; }
```

## 前置(每次最先跑)
1. 確認 `$BRAIN` 已定位(見上「定位 brain」);未定位則停止。
2. **git 操作一律對 brain repo**:`git -C "$BRAIN" …`,**絕不**寫呼叫端 cwd 的 repo。
3. 判定來源是否敏感:若來源含**祕密、客戶資料、或任何你不想公開的東西** → 產出的 note 一律 `sensitive: true`。
4. **來源去重**(讀來源前先做):`bun "$BRAIN/check.mjs" --dup <URL|影片id|路徑>`(自我定位、任何 cwd 可跑)。命中(exit 1)= 已餵過 → **停下問 user 要不要更新/略過,別重餵**;未命中(exit 0)才往下。比翻 `log.md` 可靠。

## 流程(一個來源通常觸 5-15 頁)
1. **讀來源**:`sources/` 檔 → 直接讀;URL → WebFetch;貼進的想法 → 直接用;他 repo → 讀相關檔。
   - **YouTube**:先 `yt-dlp` 抓官方/自動字幕(零成本最準、**最常見路徑**)。**真的沒字幕**才 fallback(進階):`yt-dlp -x` 下音檔 → whisper 轉錄。注意 **yt-dlp(下載)和 whisper(轉錄)是兩個不同工具**;whisper 用「當下這台機器跑得動的」(Mac=`mlx-whisper`、Win/Linux=`faster-whisper`,**別寫死**)→ 存進 `$BRAIN/sources/transcripts/`。whisper 是音轉文,專有名詞會聽錯(如 Claude→"Cloud"),抽概念前先人工校正。
2. **抽取**:先讀 `$BRAIN/lens.md`,讓萃取與取捨朝使用者判準偏。列出此來源的(a)原子概念(一個概念一則 note)、(b)提到的 entities(人/組織/產品/工具)。
3. **比對既有圖**(概念層級;來源層級去重已在前置 4 做):對每個概念/entity,先 `ls $BRAIN/notes $BRAIN/entities` + grep 既有 title/slug,**有就更新、無才新建**(避免重複節點)。
4. **建頁**:用 `$BRAIN/_templates/note.md`(或 `entity.md`)為骨,寫進 `$BRAIN/notes/<slug>.md`。新 note `status: seedling`。
   - **slug 規則**:kebab-case;**優先英文意譯**(概念無合適英文對應才用拼音)。同一概念務必沿用既有 slug,避免斷 `[[ ]]`。
5. **連結(ingest 時就建)**:note 之間、note↔entity 用 `[[<slug>]]` 雙向連;`sources` 欄填來源路徑/URL;`created` 填今天日期(向使用者要,或用對話已知日期,**不臆造**)。**互返規則**:note↔entity 連結必須雙向——note 的 `related`/`## 連結` 有 `[[entity-slug]]`,entity 的 `related`/`## 出現於` 也要有 `[[note-slug]]`,反之亦然;**不可單向連結(孤兒節點)**。
6. **補索引**:在 `$BRAIN/_index.md` 對應段加指標行;`$BRAIN/log.md` append 一行 `YYYY-MM-DD ingest — <來源> → 觸 N 頁`。
7. **體檢**(commit 前):`bun "$BRAIN/check.mjs"` 確認 **0 孤島、0 斷鏈**(斷鏈會 exit 1)。順帶看它印的 `log.md` 行數——**超過 ~300 行就 roll 成 `log-<年>.md`**。
8. **回報**:列出新建/更新的頁清單 + sensitive 標記情形。

## 規範
- 一則 note 一個想法(原子化);過長就拆。
- 連結在 ingest 時建好(非查詢時),這是跟 RAG 的根本差別。
- 用你 brain 的慣用語言撰寫。
