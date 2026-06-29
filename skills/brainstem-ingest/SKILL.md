---
name: brainstem-ingest
description: 把來源餵進你的知識圖譜(brain)。讀來源(URL / 貼進的想法 / 檔案),抽原子概念 + entities,建/更新互連的 markdown note 頁、cross-reference、補 index、寫 log。Trigger:「餵進 brain」/「ingest 這個」/「記進第二大腦」。
---

# brainstem-ingest — 餵料進你的知識圖譜

## 定位 brain(每次最先跑)
`$BRAIN` 由全域 `brainstem` 解析(BRAIN_DIR → cwd 的 `.brainroot` → 全域指標):
```bash
command -v brainstem >/dev/null || { echo "找不到 brainstem 指令 — 把 ~/.local/bin 加進 PATH 或重跑 install.sh。" >&2; exit 1; }
BRAIN="$(brainstem where)" || exit 1   # where 失敗訊息已走 stderr
```

## 前置(每次最先跑)
1. 確認 `$BRAIN` 已定位(見上「定位 brain」);未定位則停止。
2. **git 操作一律對 brain repo**:`git -C "$BRAIN" …`,**絕不**寫呼叫端 cwd 的 repo。
3. 判定來源是否敏感:若來源含**祕密、客戶資料、或任何你不想公開的東西** → 產出的 note 一律 `sensitive: true`。
4. **來源去重**(讀來源前先做):`brainstem check --dup <URL|影片id|路徑>`(自我定位、任何 cwd 可跑)。命中(exit 1)= 已餵過 → **停下問 user 要不要更新/略過,別重餵**;未命中(exit 0)才往下。比翻 `log.md` 可靠。
   - **裸 GitHub repo URL 例外**:先正規化成 canonical 形式再 `--dup`,且命中的是 repo entity 時**不停下問**,改走下節「GitHub repo 深 ingest → 增量再餵」。

## 流程(一個來源通常觸 5-15 頁)
1. **讀來源**:`sources/` 檔 → 直接讀;URL → WebFetch;貼進的想法 → 直接用;他 repo → 讀相關檔。
   - **裸 GitHub repo URL → 走下節「GitHub repo 深 ingest」深流程**(README → clone+codegraph → git log → web 評價);非裸 repo 的 GitHub URL(`/blob/`、issue、PR…)仍 WebFetch 單頁。
   - **YouTube**:先 `yt-dlp` 抓官方/自動字幕(零成本最準、**最常見路徑**)。**真的沒字幕**才 fallback(進階):`yt-dlp -x` 下音檔 → whisper 轉錄。注意 **yt-dlp(下載)和 whisper(轉錄)是兩個不同工具**;whisper 用「當下這台機器跑得動的」(Mac=`mlx-whisper`、Win/Linux=`faster-whisper`,**別寫死**)→ 存進 `$BRAIN/sources/transcripts/`。whisper 是音轉文,專有名詞會聽錯(如 Claude→"Cloud"),抽概念前先人工校正。
2. **抽取**:先讀 `$BRAIN/lens.md`,讓萃取與取捨朝使用者判準偏。列出此來源的(a)原子概念(一個概念一則 note)、(b)提到的 entities(人/組織/產品/工具)。
3. **比對既有圖**(概念層級;來源層級去重已在前置 4 做):對每個概念/entity,先 `ls $BRAIN/notes $BRAIN/entities` + grep 既有 title/slug,**有就更新、無才新建**(避免重複節點)。
4. **建頁**:用 `$BRAIN/_templates/note.md`(或 `entity.md`)為骨,寫進 `$BRAIN/notes/<slug>.md`。新 note `status: seedling`。
   - **slug 規則**:kebab-case;**優先英文意譯**(概念無合適英文對應才用拼音)。同一概念務必沿用既有 slug,避免斷 `[[ ]]`。
5. **連結(ingest 時就建)**:note 之間、note↔entity 用 `[[<slug>]]` 雙向連;`sources` 欄填來源路徑/URL;`created` 填今天日期(向使用者要,或用對話已知日期,**不臆造**)。**互返規則**:note↔entity 連結必須雙向——note 的 `related`/`## 連結` 有 `[[entity-slug]]`,entity 的 `related`/`## 出現於` 也要有 `[[note-slug]]`,反之亦然;**不可單向連結(孤兒節點)**。
6. **補索引**:在 `$BRAIN/_index.md` 對應段加指標行;`$BRAIN/log.md` append 一行 `YYYY-MM-DD ingest — <來源> → 觸 N 頁`。
7. **體檢**(commit 前):`brainstem check` 確認 **0 孤島、0 斷鏈**(斷鏈會 exit 1)。順帶看它印的 `log.md` 行數——**超過 ~300 行就 roll 成 `log-<年>.md`**。
8. **回報**:列出新建/更新的頁清單 + sensitive 標記情形。

## GitHub repo 深 ingest（裸 repo URL 專屬）

> 目的:ingest 別人的 repo 是為了**偷招**——看別人怎麼做、改善自己的 harness / AI 落地,不是做中立型錄。下面的形狀都服務這個目的。

### 觸發與 URL 正規化
- **觸發**(走本節深流程):裸 repo URL `https://github.com/<owner>/<repo>` 或 `…/tree/<branch>`。
- **不觸發**(維持「流程 step 1」WebFetch 單頁):`/blob/`(單檔)、`/issues/`、`/pull/`、`/discussions`、`/releases`、`/wiki`。
- **正規化**(進流程前先做,觸發判定與去重共用)→ canonical URL,依序:
  1. scheme 強制 `https`;
  2. host / owner / repo 一律 lowercase;
  3. 剝路徑尾段(`/tree/…`、`/blob/…`、`/issues/…`、`/pull/…` 等),只留 `<owner>/<repo>`;
  4. 去結尾 `.git`、去結尾 `/`。
  - 結果形如 `https://github.com/<owner>/<repo>`。**前置 4 的 `brainstem check --dup`、entity 的 `repo_url`、增量比對一律用這個 canonical 形式**(`--dup` 是子字串比對,不正規化會去重 miss)。

### 深流程（取代「流程 step 1」對 repo 的處理）
1. **README + meta**:`WebFetch` README;`gh api repos/<owner>/<repo>`（可選）抓 stars / 主要語言 / 最近 push / 描述 / license,抓不到就跳過該欄。
2. **clone 到 temp**:`git clone --depth 100 <canonical-url> <TEMP>`,`<TEMP>` = 本 session scratchpad 根下 `ingest-<owner>-<repo>/`（**寫死走 scratchpad,絕不落到 cwd 或 `$BRAIN`**）。`--depth 100` 限歷史深度（供 git log / 增量 diff）,不影響工作樹大小。
3. **git log**:`git -C <TEMP> log` 取近期活動（誰在改 / 改什麼主題 / 最近一次 commit 距今多久 → 還活著嗎）;記 `git -C <TEMP> rev-parse HEAD`（→ `last_commit`）與 default branch。
4. **codegraph 架構**（用 **CLI 不用 MCP**;MCP 綁呼叫端 repo 會污染使用者索引）:
   - **規模閘（init 前）**:`git -C <TEMP> ls-files | wc -l` 估檔數;**> ~5000 → 不全倉 init**,改**對最相關子目錄 init 再 query**（`codegraph init <TEMP>/<subdir>` → `codegraph query -p <TEMP>/<subdir> …` / `codegraph files -p <TEMP>/<subdir>`）、或退回讀關鍵檔,回報註明「未全倉索引」。(注意:`codegraph files`/`query` 讀的是 index,**沒先 init 就會失敗**,故大型 repo 也得先 init 子目錄。)
   - 規模 OK:`codegraph init <TEMP>` → `codegraph query -p <TEMP> …` / `codegraph files -p <TEMP>` 抓**高層地圖**（架構一句話 + 主要模組 / 進入點）,**只對看起來可偷的招式深挖**,不全倉 trace（控 query 輸出 token）。
5. **web 評價**:幾條 `WebSearch`（`<repo> review`、`<owner>/<repo> hacker news`、`<repo> reddit`、`<repo> 踩雷`）,折成 entity「評價 / 實測」段,當「這招別人實測行不行」佐證。
6. **清理**:抽取完成後 `rm -rf <TEMP>`（含 `.codegraph/`）。

### 落腦形狀（偷招型）
抽取 / 建頁接回「流程 step 2–7」（讀 lens → 比對既有圖 → 建頁 → 連結 → 補索引 → 體檢）,但形狀為:
- **1 個 repo entity 頁**（`entities/<slug>.md`）:段落 = 裝什麼 / 架構一句話（codegraph 抽）/ 評價（web）/ git 活動 / 索引狀態;front-matter 含 `repo_url`（canonical）、`default_branch`、`last_commit`、`last_ingested`（日期用對話已知日期,不臆造）。
- **N 個 concept note**:每則一招「**它怎麼做 X**」（原子化）,`[[ ]]` 連回 repo entity **並連到腦裡既有的 harness / AI 落地概念**（同招跨 repo 自動匯流）。
- 互返雙向連、`status: seedling`、lens 偏判準 全照「流程」既有規範,不留孤兒節點。

### 增量再餵（repo entity 命中時）
- **scope**:本節只在前置 4 **命中的是 repo entity**（命中檔在 `entities/`、有 `repo_url` front-matter）時生效;其他來源（YouTube / 網頁 / 貼進想法 / 路徑）命中時**維持「停下問 user」**。
- 流程:從多筆命中中以 `repo_url` 精確認出 repo entity → 讀其 `last_commit` → clone 後 `git -C <TEMP> log <last_commit>..HEAD`:
  - 有新 commit → **自動**評估增 / 修 concept note（看改動主題是否帶出新招）+ 更新 entity 的 `last_commit` / `last_ingested` / git 活動段;
  - 無新 commit → 只回報「無變化,略過」,不動頁;
  - 完了**列出改了哪幾頁**。
- 邊界:`last_commit` 不在 `--depth 100` 窗內,或上游 force-push / rebase 使其已不在遠端歷史 → 先 `git -C <TEMP> fetch origin --deepen=200`（或 `git -C <TEMP> fetch --unshallow`）;仍取不到 → 退回「摘要近期 N commit」,回報註明無法對 `last_commit` 精確 diff。

### 降級（無 codegraph CLI / clone 失敗）
不中斷:`WebFetch` README + `gh api` meta（可選）+ `WebSearch` 評價;**不跑 codegraph、不做程式碼架構抽取**,concept note 僅從 README / 評價可得範圍產生;回報標明降級原因與「未做程式碼架構分析」。

### 敏感性
照前置 3:私有 / 客戶 / 不想公開的 repo → 產出的 entity 與 concept note 一律 `sensitive: true`。

## 規範
- 一則 note 一個想法（原子化）;過長就拆。
- 連結在 ingest 時建好（非查詢時）,這是跟 RAG 的根本差別。
- 用你 brain 的慣用語言撰寫。
