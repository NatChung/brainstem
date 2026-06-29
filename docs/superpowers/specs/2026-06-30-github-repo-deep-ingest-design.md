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
- 偵測不到 `codegraph` CLI 或 `git clone` 失敗 → **不中斷**,降級。降級程度明訂為:`WebFetch` README + `gh api`(可選)抓 meta + `WebSearch` 評價;**無本地 checkout 故不跑 codegraph、不做架構抽取**,concept note 只能從 README / 評價抽得到的範圍產生。回報裡標明降級原因與「未做程式碼架構分析」。

### URL 正規化(觸發判定與去重共用)

進流程前先把使用者貼進的 URL 正規化成 **canonical repo URL**,作為去重 key 與 `repo_url` 欄位值。規則(依序套用):
1. 強制 scheme = `https`。
2. host、owner、repo 一律 **lowercase**。
3. 砍掉路徑尾段:`/tree/<branch>`、`/blob/...`、`/issues/...`、`/pull/...` 等一律剝除,只留 `<owner>/<repo>`。
4. 去結尾 `.git`、去結尾 `/`。
- 結果形如 `https://github.com/<owner>/<repo>`。**所有 `--dup` 查詢、`repo_url` 寫入、`last_commit` 比對都用這個 canonical 形式**,確保子字串去重穩定命中。

## B. 深 ingest 流程(取代現流程 step 1 對 repo 的處理)

1. **README + repo meta**:`WebFetch` README;`gh api repos/<owner>/<repo>`(可選)抓 stars / 主要語言 / 最近 push 時間 / 描述 / license,抓不到就跳過該欄。
2. **clone 到 temp**:`git clone --depth 100 <url> <TEMP>`,其中 `<TEMP>` = 本 session 的 scratchpad 根目錄下 `ingest-<owner>-<repo>/`(**寫死指引,絕不落到 cwd 或 brain repo**)。`--depth 100` 限制的是**歷史深度**(供 git log / 增量 diff),不影響工作樹大小。
3. **git log**:`git -C <temp> log` 取近期活動(誰在改、改什麼主題、最近一次 commit 距今多久 → 還活著嗎),摘要進 entity;記下 `git -C <temp> rev-parse HEAD` 的 commit SHA 與 `default_branch`。
4. **codegraph 跑架構**:在 temp clone 內用 **codegraph CLI**(`codegraph init <TEMP>` 後 `codegraph files -p <TEMP>` / `codegraph query -p <TEMP> ...`),**不是 MCP** —— MCP 綁呼叫端 repo,會污染使用者的索引。
   - **規模閘(init 前先做)**:`codegraph init` 索引的是 **checkout 出來的整棵樹**,與 clone depth 無關 → 巨倉 / monorepo 的 build 成本(時間 / CPU / 磁碟)可能爆掉。先用輕量探測(`git -C <TEMP> ls-files | wc -l` 或 `du -sh`)估規模;**超過上限(預設 ~5000 檔)→ 不全倉 init**,改**對最相關子目錄 init 再 query**(`codegraph init <TEMP>/<subdir>` 後 `codegraph files -p <TEMP>/<subdir>`)、或退回讀關鍵檔,並在回報註明「未全倉索引」。(`codegraph files`/`query` 讀 index,沒先 init 必失敗 → 大型 repo 也須先 init 子目錄,不能直接 query 整棵樹。)
   - 規模 OK → 先抓**高層地圖**:架構一句話 + 主要模組/進入點。
   - **只對看起來可偷的招式深挖**,不做全倉 trace(控 query 輸出 token)。
5. **web 評價**:幾條 `WebSearch`(例:`<repo> review`、`<owner>/<repo> hacker news`、`<repo> reddit`、`<repo> 踩雷 / 問題`),折成 entity 的「評價 / 實測」段 —— 當作「這招別人實測行不行」的佐證,而非花絮。
6. **清理**:抽取完成後 `rm -rf` 整個 temp 目錄(含 `.codegraph/`)。temp 一律走 scratchpad,不碰呼叫端 cwd、也不碰 brain repo 的 git。

## C. 落腦形狀(偷招型)

### repo entity 頁

- 內容段:**裝什麼** / **架構一句話**(codegraph 抽)/ **評價**(web)/ **git 活動**(誰在改、是否還活躍)/ 索引狀態。
- Front-matter 新增/沿用欄位:
  - `repo_url`:canonical repo URL(見 §A「URL 正規化」規則),同時是去重 key。
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

現在去重命中(`brainstem check --dup <term>` exit 1)的行為是「停下問 user」。

**scope 明確**:自動增量**只適用於命中的是 repo entity**(即命中檔位於 `entities/` 且有 `repo_url` front-matter)。其他來源(YouTube / 一般網頁 / 貼進想法 / 路徑)命中時**維持現狀「停下問 user」**,不受本節影響。

repo 命中時的自動增量:

1. 用 §A canonical URL 做 `brainstem check --dup <canonical-url>`;命中 → 從命中的多筆中認出 `entities/` 下那個 repo entity(靠 `repo_url` 欄位),讀它的 `last_commit`。
2. clone 後 `git -C <TEMP> log <last_commit>..HEAD`。
3. **有新 commit** → **自動評估**該不該新增 / 修改 concept note(看改動主題是否帶出新招),並更新 entity 的 `last_commit`、`last_ingested`、git 活動段。
4. **無新 commit** → 只回報「無變化,略過」,不動頁。
5. 完了**列出改了哪幾頁**。
6. 邊界:`last_commit` 不在 `--depth 100` 窗內(`git log A..HEAD` 報 unknown revision),**或**上游 force-push / rebase 使 `last_commit` 已不在遠端歷史 → 先 `git -C <TEMP> fetch --deepen=200`(或 `--unshallow`)加深;仍取不到 → 退回「摘要近期 N commit」,並在回報註明「無法對 last_commit 精確 diff」。

## E. 依賴與安全

- 依賴:`git`(必要)、`codegraph` CLI(`~/.local/bin/codegraph`)、`WebSearch`、`gh`(可選)。任一缺 → 對應步驟降級,不中斷整體流程。
- 敏感判定照舊:私有 / 客戶 / 不想公開的 repo → 產出 note `sensitive: true`。
- 體檢、補索引、寫 log 照現流程(`brainstem check` 確認 0 孤島 / 0 斷鏈;`log.md` append 一行)。

## F. 測試

流程邏輯由 agent 執行、**無法**單元測(URL 分類、降級走得完、增量判斷都是 agent prose 行為)。因此測試收斂成**對 `SKILL.md` 文字的 lint**,沿用 `bin/test-skills-wiring.sh` 風格,新增一支(`bin/test-ingest-github.sh` 級)斷言:

- skill 含 GitHub 深 ingest 段落(URL 正規化規則、五步流程、§D 增量、規模閘 等關鍵錨點字串都在)。
- 明確要求 **codegraph CLI(`-p`/`init <path>`)**,**未**出現會污染呼叫端的 codegraph MCP 工具呼叫(`codegraph_*` MCP 名)。
- 列出的 entity front-matter 欄位字串齊全(`repo_url` / `default_branch` / `last_commit` / `last_ingested`)。
- temp 路徑指引指向 scratchpad、未指向 cwd / brain repo。

(URL 觸發分類、降級實跑、增量正確性這類行為不在自動測涵蓋,靠手動冒煙與 review。)

## Review 後處置(2026-06-30)

收到 doc review,已折進:Critical(URL 正規化規則寫死 + 接上 `--dup`,見 §A)、`fetch --deepen=N`/`--unshallow`(§D.6)、§D scope 限 repo entity、§F 收斂成文件 lint、§B 巨倉規模閘、§A 降級程度與 scratchpad 路徑指引。

延後處置(實作時注意,非缺陷):
- `--dup` 子字串可能誤命中前綴相同的 repo(`owner/repo` vs `owner/repo-2`)→ 多筆命中時靠 §D.1「以 `repo_url` 欄位精確比對」消歧。
- concept note「跨 repo 匯流」效果在空腦初期會延後(無既有 harness 概念可連),靠互返規則不致成孤島。

## 開放問題

無(設計階段的分岔都已拍板:github URL 自動深跑、偷招型落腦、自動增量更新)。
