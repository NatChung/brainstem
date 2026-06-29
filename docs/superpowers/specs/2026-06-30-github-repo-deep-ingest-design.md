# GitHub repo 深度 ingest — 設計

- **日期**:2026-06-30
- **狀態**:設計通過,待寫實作計畫
- **影響面**:`skills/brainstem-ingest/SKILL.md`(指令檔);新增一支 `bin/` 冒煙測試

## 目的

使用者 ingest 別人的 GitHub repo,**不是**要做中立的「這專案是什麼」型錄,而是要**偷招** —— 看別人怎麼做,用來改善自己的 harness / AI 落地方式。整個流程的形狀都服務這個目的。

今天 `brainstem-ingest` 對 repo 的處理只有一句「他 repo → 讀相關檔」。本設計把 **裸 GitHub repo URL** 升級成深流程:README → clone 到 temp + codegraph 看架構 → git log 看活動 → web 找評價 → 落進腦圖。

## 範圍

- **改的是 skill 指令檔**(`brainstem-ingest`),邏輯由 agent 執行,不是新寫一支程式。
- 落腦形狀:`偷招型`(repo entity = 索引+判斷;concept note = 可搬的招式並連到既有 harness 概念)。
- 含「再次餵同一 repo → 看新 git log → 自動增量更新」。

非範圍:其他來源型別(YouTube / 貼進想法 / 一般網頁)維持現狀;不改 query / synthesize skill。

## A. 觸發判定

只有 **裸 repo URL** 觸發深流程:

- 觸發:`https://github.com/<owner>/<repo>`、`https://github.com/<owner>/<repo>/tree/<branch>`。
- **不**觸發(維持現狀,WebFetch 讀單頁即可):指向單一檔案(`/blob/`)、issue、PR、discussion、releases、wiki 的 URL。
- 偵測不到 `codegraph` CLI 或 `git clone` 失敗 → **不中斷**,降級成「讀關鍵檔 + README」,並在回報裡標明降級原因。

## B. 深 ingest 流程(取代現流程 step 1 對 repo 的處理)

1. **README + repo meta**:`WebFetch` README;`gh api repos/<owner>/<repo>`(可選)抓 stars / 主要語言 / 最近 push 時間 / 描述 / license,抓不到就跳過該欄。
2. **clone 到 temp**:`git clone --depth 100 <url> <scratchpad>/ingest-<owner>-<repo>`。depth 100 取近期歷史、又不拖垮巨倉。
3. **git log**:`git -C <temp> log` 取近期活動(誰在改、改什麼主題、最近一次 commit 距今多久 → 還活著嗎),摘要進 entity;記下 `git -C <temp> rev-parse HEAD` 的 commit SHA 與 `default_branch`。
4. **codegraph 跑架構**:在 temp clone 內用 **codegraph CLI**(`codegraph init` 後 query),**不是 MCP** —— MCP 綁呼叫端 repo,會污染使用者的索引。
   - 先抓**高層地圖**:架構一句話 + 主要模組/進入點。
   - **只對看起來可偷的招式深挖**,不做全倉 trace(控 token)。
5. **web 評價**:幾條 `WebSearch`(例:`<repo> review`、`<owner>/<repo> hacker news`、`<repo> reddit`、`<repo> 踩雷 / 問題`),折成 entity 的「評價 / 實測」段 —— 當作「這招別人實測行不行」的佐證,而非花絮。
6. **清理**:抽取完成後 `rm -rf` 整個 temp 目錄(含 `.codegraph/`)。temp 一律走 scratchpad,不碰呼叫端 cwd、也不碰 brain repo 的 git。

## C. 落腦形狀(偷招型)

### repo entity 頁

- 內容段:**裝什麼** / **架構一句話**(codegraph 抽)/ **評價**(web)/ **git 活動**(誰在改、是否還活躍)/ 索引狀態。
- Front-matter 新增/沿用欄位:
  - `repo_url`:正規化後的 `https://github.com/<owner>/<repo>`(去重 key)。
  - `default_branch`
  - `last_commit`:上次餵到的 HEAD SHA。
  - `last_ingested`:日期(用對話已知日期,不臆造)。

### concept note(金礦)

- 每則一招「**它怎麼做 X**」(例:它怎麼做 plan→execute 的交接、它怎麼壓 token),原子化、一則一想法。
- `[[ ]]` 連回 repo entity,**並連到腦裡既有的 harness / AI 落地概念** —— 讓同一招在不同 repo 出現時自動匯流到同一個你關心的主題。
- `sources` 欄填 repo URL;`status: seedling`(新 note)。
- 互返規則照現流程:note↔entity 雙向連,不留孤兒。

`lens.md` 照舊把萃取偏向使用者判準。

## D. 增量再餵(改現流程「前置 4 去重」)

現在去重命中(`brainstem check --dup <URL>` exit 1)的行為是「停下問 user」。新行為改成自動增量:

1. 命中已餵過的 repo → 讀 entity 的 `last_commit`。
2. clone 後 `git -C <temp> log <last_commit>..HEAD`。
3. **有新 commit** → **自動評估**該不該新增 / 修改 concept note(看改動主題是否帶出新招),並更新 entity 的 `last_commit`、`last_ingested`、git 活動段。
4. **無新 commit** → 只回報「無變化,略過」,不動頁。
5. 完了**列出改了哪幾頁**。
6. 邊界:`last_commit` 不在 `--depth 100` 窗內(`git log A..HEAD` 報 unknown revision)→ `git fetch --deepen` 加深,仍不行則退回「摘要近期 N commit」並在回報註明無法精確 diff。

## E. 依賴與安全

- 依賴:`git`(必要)、`codegraph` CLI(`~/.local/bin/codegraph`)、`WebSearch`、`gh`(可選)。任一缺 → 對應步驟降級,不中斷整體流程。
- 敏感判定照舊:私有 / 客戶 / 不想公開的 repo → 產出 note `sensitive: true`。
- 體檢、補索引、寫 log 照現流程(`brainstem check` 確認 0 孤島 / 0 斷鏈;`log.md` append 一行)。

## F. 測試

沿用 `bin/` 既有 bash 測試風格,新增一支冒煙(`bin/test-ingest-github.sh` 級):

- 邏輯在 agent、不可單元測,故測試聚焦**可驗的慣例**:
  - URL 觸發判定:裸 repo URL vs `/blob/`、issue URL 的分類正確。
  - entity front-matter 欄位齊全(`repo_url` / `default_branch` / `last_commit` / `last_ingested`)。
  - 降級路徑:codegraph 缺席時仍走得完、回報有標降級。
- skill 指令檔本身可加 lint:確認新增段落存在、未引入會污染呼叫端的 codegraph MCP 呼叫。

## 開放問題

無(設計階段的分岔都已拍板:github URL 自動深跑、偷招型落腦、自動增量更新)。
