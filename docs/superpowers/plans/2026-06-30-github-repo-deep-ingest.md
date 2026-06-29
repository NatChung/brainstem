# GitHub repo 深度 ingest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 `brainstem-ingest` 對裸 GitHub repo URL 走「README → clone+codegraph → git log → web 評價 → 偷招型落腦 + 增量再餵」深流程。

**Architecture:** 純編輯一個 skill 指令檔(`skills/brainstem-ingest/SKILL.md`)——流程邏輯由 agent 執行,不寫程式;以一支 bash「文件 lint」(`bin/test-ingest-github.sh`,沿用 `test-skills-wiring.sh` 風格)斷言 skill 文字含所有關鍵錨點,作為 TDD 的紅/綠 gate。部署 = 重跑 `install.sh` 把 skill 複製到 `~/.claude/skills/`。

**Tech Stack:** Bash(POSIX/`grep` lint)、Markdown skill 指令檔。執行期工具:`git`、`codegraph` CLI(`~/.local/bin`)、`WebFetch`/`WebSearch`、`gh`(可選)。

## Global Constraints

- 本檔與 skill 指令一律**中文**(repo 語言政策;technical terms 英文 OK)。
- **絕不** commit 任何個人 note / 設定過的 lens 進此公開 repo。
- temp 一律走**本 session scratchpad 根**,絕不落到 cwd 或 `$BRAIN`;用完 `rm -rf`。
- git 操作:skill 內對 brain 用 `git -C "$BRAIN"`;對 temp clone 用 `git -C <TEMP>`;**絕不**碰呼叫端 cwd 的 repo。
- codegraph 在 temp clone 一律用 **CLI**(`codegraph init <path>` / `-p <path>`),**禁用** codegraph MCP 工具(`codegraph_*`)——MCP 綁呼叫端 repo 會污染使用者索引。
- canonical repo URL 形式固定為 `https://github.com/<owner>/<repo>`(lowercase、剝 `/tree`·`/blob`·尾段、去 `.git`/尾斜線);**所有** `--dup` 查詢、`repo_url` 寫入、`last_commit` 比對都用它。
- 對應 spec:`docs/superpowers/specs/2026-06-30-github-repo-deep-ingest-design.md`。

---

### Task 1: GitHub 深 ingest 段落寫進 skill(lint-gated)

**Files:**
- Create: `bin/test-ingest-github.sh`
- Modify: `skills/brainstem-ingest/SKILL.md`(前置 4 第 19 行、流程 step 1 第 22 行、檔尾新增「GitHub repo 深 ingest」整節)

**Interfaces:**
- Consumes: 既有 skill 的「定位 brain」「前置 1-4」「流程 step 2-7」「規範」段落(深流程接回 step 2-7 抽取/建頁/連結/索引/體檢)。
- Produces: skill 內新增「GitHub repo 深 ingest」節 + 兩處接點;`bin/test-ingest-github.sh` 通過。後續無其他 task 依賴其符號。

- [ ] **Step 1: 寫 lint 測試(failing test)**

Create `bin/test-ingest-github.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/skills/brainstem-ingest/SKILL.md"

# 深 ingest 段落存在
grep -q 'GitHub repo 深 ingest' "$F" || { echo "FAIL: missing GitHub deep-ingest section"; exit 1; }
# canonical URL 形式 + 正規化規則
grep -q 'https://github.com/<owner>/<repo>' "$F" || { echo "FAIL: missing canonical repo URL form"; exit 1; }
grep -q 'lowercase' "$F" || { echo "FAIL: missing normalization (lowercase)"; exit 1; }
grep -q '\.git' "$F" || { echo "FAIL: missing normalization (strip .git)"; exit 1; }
# clone 到 temp(shallow depth + scratchpad 指引)
grep -q 'git clone --depth 100' "$F" || { echo "FAIL: missing shallow clone"; exit 1; }
grep -q 'scratchpad' "$F" || { echo "FAIL: missing scratchpad temp guidance"; exit 1; }
# codegraph CLI 而非 MCP
grep -q 'codegraph init' "$F" || { echo "FAIL: missing codegraph CLI init"; exit 1; }
grep -q 'codegraph files -p' "$F" || { echo "FAIL: missing codegraph CLI -p path flag"; exit 1; }
! grep -q 'codegraph_' "$F" || { echo "FAIL: must not reference codegraph MCP tools"; exit 1; }
# 巨倉規模閘
grep -q '5000' "$F" || { echo "FAIL: missing huge-repo size guard"; exit 1; }
# entity front-matter 欄位齊全
for field in repo_url default_branch last_commit last_ingested; do
  grep -q "$field" "$F" || { echo "FAIL: missing front-matter field $field"; exit 1; }
done
# 增量 deepen 修正(=N 或 unshallow,非裸 --deepen)
grep -qE 'deepen=[0-9]|--unshallow' "$F" || { echo "FAIL: missing fetch --deepen=N/--unshallow"; exit 1; }
# 增量再餵節
grep -q '增量再餵' "$F" || { echo "FAIL: missing incremental re-ingest section"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: 跑測試確認 fail**

Run: `bash bin/test-ingest-github.sh`
Expected: 印 `FAIL: missing GitHub deep-ingest section`,exit 1(skill 尚未有新段落)。

- [ ] **Step 3: 接點 1 — 改前置 4(SKILL.md 第 19 行)**

把第 19 行末尾補上 repo 指引。將:

```
4. **來源去重**(讀來源前先做):`brainstem check --dup <URL|影片id|路徑>`(自我定位、任何 cwd 可跑)。命中(exit 1)= 已餵過 → **停下問 user 要不要更新/略過,別重餵**;未命中(exit 0)才往下。比翻 `log.md` 可靠。
```

改成:

```
4. **來源去重**(讀來源前先做):`brainstem check --dup <URL|影片id|路徑>`(自我定位、任何 cwd 可跑)。命中(exit 1)= 已餵過 → **停下問 user 要不要更新/略過,別重餵**;未命中(exit 0)才往下。比翻 `log.md` 可靠。
   - **裸 GitHub repo URL 例外**:先正規化成 canonical 形式再 `--dup`,且命中的是 repo entity 時**不停下問**,改走下節「GitHub repo 深 ingest → 增量再餵」。
```

- [ ] **Step 4: 接點 2 — 改流程 step 1(SKILL.md 第 22 行)**

將第 22 行:

```
1. **讀來源**:`sources/` 檔 → 直接讀;URL → WebFetch;貼進的想法 → 直接用;他 repo → 讀相關檔。
```

改成:

```
1. **讀來源**:`sources/` 檔 → 直接讀;URL → WebFetch;貼進的想法 → 直接用;他 repo → 讀相關檔。
   - **裸 GitHub repo URL → 走下節「GitHub repo 深 ingest」深流程**(README → clone+codegraph → git log → web 評價);非裸 repo 的 GitHub URL(`/blob/`、issue、PR…)仍 WebFetch 單頁。
```

- [ ] **Step 5: 新增整節「GitHub repo 深 ingest」(append 到 SKILL.md「## 規範」之前)**

插入以下整節:

```markdown
## GitHub repo 深 ingest(裸 repo URL 專屬)

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

### 深流程(取代「流程 step 1」對 repo 的處理)
1. **README + meta**:`WebFetch` README;`gh api repos/<owner>/<repo>`(可選)抓 stars / 主要語言 / 最近 push / 描述 / license,抓不到就跳過該欄。
2. **clone 到 temp**:`git clone --depth 100 <canonical-url> <TEMP>`,`<TEMP>` = 本 session scratchpad 根下 `ingest-<owner>-<repo>/`(**寫死走 scratchpad,絕不落到 cwd 或 `$BRAIN`**)。`--depth 100` 限歷史深度(供 git log / 增量 diff),不影響工作樹大小。
3. **git log**:`git -C <TEMP> log` 取近期活動(誰在改 / 改什麼主題 / 最近一次 commit 距今多久 → 還活著嗎);記 `git -C <TEMP> rev-parse HEAD`(→ `last_commit`)與 default branch。
4. **codegraph 架構**(用 **CLI 不用 MCP**;MCP 綁呼叫端 repo 會污染使用者索引):
   - **規模閘(init 前)**:`git -C <TEMP> ls-files | wc -l` 估檔數;**> ~5000 → 不全倉 init**,改 `codegraph files -p <TEMP>` 鎖定少數最相關子目錄、或退回讀關鍵檔,回報註明「未全倉索引」。
   - 規模 OK:`codegraph init <TEMP>` → `codegraph query -p <TEMP> …` / `codegraph files -p <TEMP>` 抓**高層地圖**(架構一句話 + 主要模組 / 進入點),**只對看起來可偷的招式深挖**,不全倉 trace(控 query 輸出 token)。
5. **web 評價**:幾條 `WebSearch`(`<repo> review`、`<owner>/<repo> hacker news`、`<repo> reddit`、`<repo> 踩雷`),折成 entity「評價 / 實測」段,當「這招別人實測行不行」佐證。
6. **清理**:抽取完成後 `rm -rf <TEMP>`(含 `.codegraph/`)。

### 落腦形狀(偷招型)
抽取 / 建頁接回「流程 step 2–7」(讀 lens → 比對既有圖 → 建頁 → 連結 → 補索引 → 體檢),但形狀為:
- **1 個 repo entity 頁**(`entities/<slug>.md`):段落 = 裝什麼 / 架構一句話(codegraph 抽)/ 評價(web)/ git 活動 / 索引狀態;front-matter 含 `repo_url`(canonical)、`default_branch`、`last_commit`、`last_ingested`(日期用對話已知日期,不臆造)。
- **N 個 concept note**:每則一招「**它怎麼做 X**」(原子化),`[[ ]]` 連回 repo entity **並連到腦裡既有的 harness / AI 落地概念**(同招跨 repo 自動匯流)。
- 互返雙向連、`status: seedling`、lens 偏判準 全照「流程」既有規範,不留孤兒節點。

### 增量再餵(repo entity 命中時)
- **scope**:本節只在前置 4 **命中的是 repo entity**(命中檔在 `entities/`、有 `repo_url` front-matter)時生效;其他來源(YouTube / 網頁 / 貼進想法 / 路徑)命中時**維持「停下問 user」**。
- 流程:從多筆命中中以 `repo_url` 精確認出 repo entity → 讀其 `last_commit` → clone 後 `git -C <TEMP> log <last_commit>..HEAD`:
  - 有新 commit → **自動**評估增 / 修 concept note(看改動主題是否帶出新招)+ 更新 entity 的 `last_commit` / `last_ingested` / git 活動段;
  - 無新 commit → 只回報「無變化,略過」,不動頁;
  - 完了**列出改了哪幾頁**。
- 邊界:`last_commit` 不在 `--depth 100` 窗內,或上游 force-push / rebase 使其已不在遠端歷史 → 先 `git -C <TEMP> fetch --deepen=200`(或 `--unshallow`);仍取不到 → 退回「摘要近期 N commit」,回報註明無法對 `last_commit` 精確 diff。

### 降級(無 codegraph CLI / clone 失敗)
不中斷:`WebFetch` README + `gh api` meta(可選)+ `WebSearch` 評價;**不跑 codegraph、不做程式碼架構抽取**,concept note 僅從 README / 評價可得範圍產生;回報標明降級原因與「未做程式碼架構分析」。

### 敏感性
照前置 3:私有 / 客戶 / 不想公開的 repo → 產出的 entity 與 concept note 一律 `sensitive: true`。
```

- [ ] **Step 6: 跑 lint 確認 PASS**

Run: `bash bin/test-ingest-github.sh`
Expected: 印 `PASS`,exit 0。

- [ ] **Step 7: 跑既有 wiring 測試確認無回歸**

Run: `bash bin/test-skills-wiring.sh`
Expected: 印 `PASS`(前置 4 的 `brainstem check --dup`、`brainstem where`、PATH probe 等錨點仍在)。

- [ ] **Step 8: 把新測試登錄進 CLAUDE.md 測試清單**

Modify `CLAUDE.md`「## 本機測試」區塊,在 `bash bin/test-ac4.sh` 後一行加入:

```
bash bin/test-ingest-github.sh
```

- [ ] **Step 9: Commit**

```bash
git add bin/test-ingest-github.sh skills/brainstem-ingest/SKILL.md CLAUDE.md
git commit -m "feat(ingest): 裸 GitHub repo URL 走 clone+codegraph+web 評價深流程 + 增量再餵"
```

---

### Task 2: 部署到本機 + 手動冒煙

**Files:**
- 無檔案改動(部署 + 人工驗證)。

**Interfaces:**
- Consumes: Task 1 完成的 `skills/brainstem-ingest/SKILL.md`。
- Produces: 無(驗證性 task)。

- [ ] **Step 1: 重跑 install.sh 把 skill 複製到 `~/.claude/skills/`**

Run: `bash install.sh`
Expected: 結尾印安裝成功訊息;`~/.claude/skills/brainstem-ingest/SKILL.md` 內容含「GitHub repo 深 ingest」節。

驗證:

Run: `grep -c '## GitHub repo 深 ingest' ~/.claude/skills/brainstem-ingest/SKILL.md`
Expected: `1`(以節標題為唯一錨點;裸字串 `GitHub repo 深 ingest` 因兩處接點會數到 3)

- [ ] **Step 2: 手動冒煙(正常路徑,小 repo)**

在一個有 `.brainroot` 的測試腦目錄(或 `brainstem init /tmp/demo-brain` 新建)下,對 Claude 說「ingest https://github.com/<owner>/<small-repo>」,人工確認:
- clone 落在 scratchpad(非 cwd / 非 `$BRAIN`),結束後 temp 已刪;
- 產生 1 個 `entities/` 頁,front-matter 有 `repo_url`/`default_branch`/`last_commit`/`last_ingested`;
- concept note 連回 entity 且互返不留孤兒;
- `brainstem check` 0 孤島 0 斷鏈。

- [ ] **Step 3: 手動冒煙(增量路徑)**

對**同一 repo** 再 ingest 一次,確認:走「增量再餵」、不重建重複節點;若無新 commit 回報「無變化,略過」。

- [ ] **Step 4: 手動冒煙(降級路徑)**

對一個 `/issues/...` 或 `/blob/...` URL ingest,確認**不**觸發 clone、只 WebFetch 單頁(回歸保護)。

---

## Self-Review

**Spec coverage**(對 spec 各節):
- §A 觸發 + URL 正規化 → Task 1 Step 4(觸發判定)、Step 5「觸發與 URL 正規化」+ lint(`lowercase`/`.git`/canonical)。✅
- §A 降級程度 → Step 5「降級」節 + Task 2 Step 4 冒煙。✅
- §B 深流程五步(README/clone/log/codegraph/評價/清理)→ Step 5「深流程」。✅
- §B 規模閘 → Step 5 codegraph 子項 + lint(`5000`)。✅
- §C 落腦形狀(entity + concept note + front-matter 欄位)→ Step 5「落腦形狀」+ lint(四欄位)。✅
- §D 增量再餵 + scope 限 repo entity + `--deepen=N` → Step 3(接點)+ Step 5「增量再餵」+ lint(`增量再餵`/`deepen=N`)。✅
- §E 依賴 / 安全(CLI 非 MCP、temp 走 scratchpad) → Global Constraints + lint(`codegraph_` 禁用、`scratchpad`)。✅
- §F 文件 lint → Task 1 整體即 lint 驅動。✅

**Placeholder scan:** 無 TBD/TODO;每個 code/edit step 都給出實際 grep 行或 verbatim markdown。✅

**Type consistency:** lint 錨點字串與 Step 5 插入文字逐一對齊(`codegraph files -p`、`deepen=200`、`~5000`、四欄位、`增量再餵`、`https://github.com/<owner>/<repo>`)。✅
