# 設計:引擎與腦分離(location-agnostic engine)

- 日期:2026-06-27
- 狀態:v2 — 已納入 code-review 修正與鎖定決策,待最終 review
- 範圍:改引擎設計,適用所有使用者

## 問題

brainstem 是**公開的引擎/範本**(MIT、README 主打「clone 下來養出第二大腦」、skills 全域)。但「腦的內容」(`notes/`、`entities/`、`lens.md`、`log.md`、`docs/drafts/`)跟引擎放在**同一個 repo 根**——使用者(含引擎作者)一旦繼續餵料,私人想法就跟著進這個準備公開的 repo。

根因:引擎 repo 根同時放了 `.brainroot` + `lens.md` + seed `notes/`/`entities/`,所以它「身兼引擎與一顆腦」。`check.mjs` 又把腦寫死成自己所在目錄(`dirname(import.meta.url)`),把腦永遠釘在引擎裡。

### 現況:三個元件對「腦在哪」解析不一致

| 元件 | 怎麼定位腦 | 綁引擎位置? |
|---|---|---|
| 3 個 skills | cwd 往上找 `.brainroot`(inline shell) | 否 |
| `doctor.mjs` | `BRAIN_DIR` env ‖ 否則自己所在目錄 | 半 |
| `check.mjs` | 寫死 `dirname(import.meta.url)` | 是 |
| `lens.md` / `.brainroot` / `notes/` | 引擎 repo 根 | 是 |

## 驗收標準(專案擁有者的 4 個目標)

本 spec 以是否達成這四點為主要評斷:

1. **skills 全域**:裝完後任何 repo 可呼叫。
2. **init 後:skills 全域;`lens.md` 與腦的位置在別處,且與「全域安裝」掛勾**——存在一份**全域的「腦在哪」記錄**,而非只靠 cwd→`.brainroot` 上行搜尋。
3. **裝完引擎 repo 原則上不再需要;但若日後要搬腦,要有處理途徑**——至少能用 `brainstem-query`(自然語言)問到腦在哪;腦位置是**可查、可改**的全域設定,獨立於 repo。
4. **裝完引擎 repo 不再有變動、可以刪**:runtime 任何環節都不得依賴引擎 repo 還在 disk 上。

## 鎖定決策(brainstorming + review 後)

- **散佈/升級模型 = 複製到全域家 + `VERSION` 戳記**(非 symlink、非 bake repo 路徑、非 Claude Code plugin)。
  - 理由:① 不鎖平台——複製只是搬檔,skills 可裝進任何 runtime 的 skills 目錄、`brainstem` CLI 純 shell 到處跑,未來支援 Codex 近乎零成本(plugin 的散佈/版號只在 Claude Code 成立)。② 乾淨滿足 AC4(全域家自足 → repo 可刪)。③ brainstem 主幹是 CLI 不是 skill,plugin 套不上這條 CLI。④ 最簡、貼合既有 clone+install.sh。⑤ 版號自己做便宜(`VERSION` 檔 + `brainstem --version`)。
  - 升級路徑:重 clone 最新 repo + 重跑 `install.sh`(覆寫全域家、bump VERSION)。未來要 Claude Code 市集曝光可再補一層 plugin manifest,不互斥。
- **「腦在哪/換腦」介面 = CLI 為準 + query 轉達**:`brainstem where` / `brainstem use <dir>` 是正官來源(讀/寫全域 config);`brainstem-query` 被自然語言問「我腦在哪」時轉呼叫 `brainstem where`。

## 目標 / 非目標

**目標**:引擎對「腦在哪」完全不關心;腦 = 任何含 `.brainroot` 的私有目錄;引擎(skills + CLI + 腳本)複製式全域安裝,repo 可刪;腦位置是可查可改的全域設定。

**非目標(YAGNI)**:不做引擎 repo 內的 demo 腦(只出 `_brain-template/`);不做多 profile / 多 lens 切換;不碰 ingest/query/synthesize 的**萃取邏輯**(只改它們「定位腦」與「呼叫 check」這兩處);不做網路型自動更新(`doctor` 至多本地比對 VERSION,不連遠端);現階段不打 Claude Code plugin(預留未來)。

## 設計

### A. 統一「腦在哪」解析 + 全域指標

新增 `lib/find-brain.mjs`,匯出解析函式,**優先序**:

1. `BRAIN_DIR` 環境變數(後門 / 測試)——**直接採信,不要求該路徑含 `.brainroot`**(`bin/test-doctor.sh` case C 依賴此放寬;與第 3 級不同,刻意保留不對稱)。
2. 從 `process.cwd()` 往上走找第一個含 `.brainroot` 的目錄(你正待在某顆腦裡 → 該腦勝出)。
3. **全域指標**:`$XDG_CONFIG_HOME/brainstem/config.json`(預設 `~/.config/brainstem/config.json`),格式 `{ "brain": "/abs/path" }` → 用其 `brain`(需該路徑仍含 `.brainroot`,否則視為失效、當作未設定)。
4. 都沒有 → 丟可讀錯誤(**寫 stderr**,非 stdout)並 exit 1:`找不到腦 — cd 進一顆,或 brainstem init <dir> / brainstem use <dir>。`

**實作入口**:`lib/find-brain.mjs` 同時(a)匯出解析函式給 `check.mjs`/`doctor.mjs` import(三者同被複製進 `ENGINE_HOME`,相對 import `./lib/find-brain.mjs` 成立),且(b)**可直接被當 CLI 跑**——`bun ENGINE_HOME/lib/find-brain.mjs` 解析成功印絕對路徑到 stdout、失敗印錯誤到 stderr + exit 1。`brainstem where` = 這支直跑。skills 改成 `BRAIN="$(brainstem where)"`(見 F),全圖**單一解析實作**(取代現行 `bin/brain-root.sh` 與 skills 各自的 inline walk)。

### B. 引擎全域家(複製模型)+ VERSION + repo 可刪

定義 `ENGINE_HOME = $XDG_DATA_HOME/brainstem`(預設 `~/.local/share/brainstem`)。`install.sh` 把**引擎 runtime 複製**進去(非 symlink):

```
~/.local/share/brainstem/
  check.mjs  doctor.mjs  init.mjs
  lib/find-brain.mjs
  _brain-template/…        # 開新腦的骨架(內含 _templates/note.md+entity.md;見 E)
  VERSION
```

skills **複製**(非 symlink)成真實檔到 `~/.claude/skills/brainstem-{ingest,query,synthesize}`。CLI dispatcher 裝到 `~/.local/bin/brainstem`,內部只引用固定的 `ENGINE_HOME`(**不 bake repo 路徑**)。

→ 裝完後,skills / CLI / 範本 全在 repo 外的固定位置;**刪掉 repo 不影響 runtime**(滿足 AC4)。引擎根跑 `brainstem check` 因引擎根無 `.brainroot` 且未設全域指標 → 正確報「找不到腦」。

### C. 全域 `brainstem` CLI(dispatcher)

```
brainstem where            # 印解析到的腦路徑(A 的優先序);找不到 → 提示 + exit 1
brainstem use <dir>        # 把全域指標寫成 <dir>(需含 .brainroot,否則拒絕)
brainstem init <dir>       # 複製 ENGINE_HOME/_brain-template → <dir>;<dir> 已是腦則拒絕;
                           #   若全域指標尚未設定,順手 use 這顆(第一顆即預設腦)
brainstem check [--dup <src>]   # bun ENGINE_HOME/check.mjs(腦由 find-brain 解析)
brainstem doctor           # bun ENGINE_HOME/doctor.mjs
brainstem --version        # cat ENGINE_HOME/VERSION
brainstem --help           # 列出子命令
```

- `init <dir>`:`<dir>` 不存在 → 建立;已含 `.brainroot` → 拒絕並提示;存在且非空但無 `.brainroot` → 拒絕(不冒險合併),提示換空目錄或先清。完成後印「下一步:`cd <dir>`,用 Claude Code 開啟說 hi 走 onboarding」,並建議 `git init` + 設**私有** remote(不強制、不代跑)。
- **實作分工**:CLI dispatcher 是純 POSIX shell,只做分派;有狀態的動作交給 `ENGINE_HOME` 下的 Node 腳本:
  - `brainstem where` → `bun ENGINE_HOME/lib/find-brain.mjs`(A 的入口)。
  - `brainstem use <dir>` 與 `init` 的「寫全域指標」→ `bun ENGINE_HOME/lib/config.mjs set <dir>`:把 `<dir>` **正規化成絕對路徑**、驗證含 `.brainroot`(`use` 必驗;`init` 寫的是剛建好的腦)、`mkdir -p` config 目錄、寫 `{ "brain": "<abs>" }`。`use` 對無 `.brainroot` 的 `<dir>` 拒絕並 exit 1。
  - `init <dir>` = 複製 `_brain-template/` + (指標未設定時)`config.mjs set <dir>`。
  - `check`/`doctor` → `bun ENGINE_HOME/{check,doctor}.mjs`;`--version` → `cat ENGINE_HOME/VERSION`。

### D. `install.sh`(複製式、idempotent = 升級)

1. `ROOT` = repo;`ENGINE_HOME=${XDG_DATA_HOME:-$HOME/.local/share}/brainstem`。
2. `mkdir -p` 全域家,**複製** `check.mjs doctor.mjs init.mjs lib/ _brain-template/ VERSION` 進去(`_templates/` 已含於 `_brain-template/` 內;覆寫 = 升級)。
3. **複製** `skills/brainstem-*` → `~/.claude/skills/`(真實檔,非 symlink)。
4. 寫 `~/.local/bin/brainstem`(內容引用固定 `ENGINE_HOME`)、`chmod +x`。
5. PATH 檢查:若 `~/.local/bin` 不在 `$PATH`,印**明顯**提示(偵測 `case ":$PATH:"`,建議加進 shell rc;**不自動改** rc)。因 skills 改用 `brainstem where`(見 F),PATH 沒設好會讓**每次 skill 呼叫**都 `command not found` → 此提示是 AC1 的關鍵,不可只輕描淡寫。
6. idempotent:重跑即覆寫升級;印新舊 `VERSION`。
7. **既有 `bin/` 測試同步**(複製模型的連帶):
   - `bin/test-install.sh:10` 斷言 `[ -L … ]`(symlink)→ 改 `[ -e … ] && [ ! -L … ]`(真實檔、非 symlink);並加驗 `~/.local/bin/brainstem`、`ENGINE_HOME/VERSION` 存在。
   - `bin/brain-root.sh`(現行 `.brainroot` 上行 walk)由 `lib/find-brain.mjs` / `brainstem where` 取代 → 退役(刪除或改成轉呼叫 `brainstem where`)。
   - `bin/test-brain-root.sh`、`bin/test-doctor.sh` retarget 到 `brainstem where` / `brainstem doctor`(case C 的 `BRAIN_DIR` 不需 `.brainroot` 之依賴,對應 A 第 1 級的放寬,保留)。

### E. `_brain-template/` —— 開新腦的完整骨架

```
_brain-template/
  .brainroot
  CLAUDE.md                       # 腦版 onboarding(見 G)
  lens.md                         # 未設定範本 = git show HEAD:lens.md(含 LENS_UNCONFIGURED)
  log.md                          # 空(或一行表頭)
  .gitignore                      # 從現行 .gitignore 複製(.env / *.mp3 等)
  _index.md                       # 含兩筆 seed 指標(notes/atomic… + entities/brainstem)
  _templates/
    note.md                       # 移自現行 _templates/(skill 建頁用)
    entity.md                     #   同上。 _templates/lens.md 不收(無人用,避免雙來源)
  notes/
    .gitkeep
    atomic-note-one-idea.md       # 現行 seed note 移來
  entities/
    .gitkeep
    brainstem.md                  # 現行 seed entity 移來
  sources/transcripts/.gitkeep    # ingest 轉錄落點
  docs/drafts/.gitkeep            # synthesize 落點
```

`init` 整包複製,lens 留未設定 → 第一次在新腦開 Claude Code 由其 `CLAUDE.md` 觸發 onboarding。

### F. Skills 編輯(解 review C3/C4)

非目標原宣稱「skills 不用改」是錯的;skills 有兩類 repo 耦合要改,**其餘 `$BRAIN/…`(lens/notes/entities/_templates/_index/log/sources/docs)維持不變,因為那些都是腦本地、由範本帶齊**:

1. **定位腦**:三個 SKILL.md 開頭的 inline `.brainroot` walk(各約 line 11–12)→ 改成先探 `brainstem` 在不在 PATH,再解析:
   ```sh
   command -v brainstem >/dev/null || { echo "找不到 brainstem 指令 — 把 ~/.local/bin 加進 PATH,或重跑 install.sh。" >&2; exit 1; }
   BRAIN="$(brainstem where)" || exit 1   # where 失敗訊息已走 stderr
   ```
   解析優先序與全域指標統一由 CLI 提供;PATH 探測避免「裝了但沒進 PATH」時 skill 默默 `command not found`(見 D.5)。
2. **呼叫 check**:
   - `brainstem-ingest/SKILL.md:19`:`bun "$BRAIN/check.mjs" --dup <src>` → `brainstem check --dup <src>`。
   - `brainstem-ingest/SKILL.md:30`、`brainstem-synthesize/SKILL.md:40`:`bun "$BRAIN/check.mjs"` → `brainstem check`。
3. **query 轉達位置**:`brainstem-query/SKILL.md` 加一條:被問「我腦在哪 / 換腦」時,跑 `brainstem where`(或引導 `brainstem use <dir>`)作答。滿足 AC3。

### G. 兩種 CLAUDE.md(角色分裂)

- **`_brain-template/CLAUDE.md`(腦版,使用者實際用的)**:由現行 CLAUDE.md 改寫——保留 onboarding 三步、原子筆記紀律、lens 訪談、語言政策;但
  - 移除「先跑 install.sh symlink skills」整段(引擎已全域裝好)。
  - 第 0 步環境預檢 `bun run doctor` → `brainstem doctor`。
  - 工具段 `bun run brain` → `brainstem check`;去重 `bun run brain --dup` → `brainstem check --dup`。
  - 提及「腦在哪可 `brainstem where` 查、`brainstem use` 改」。
- **引擎 repo 根 `CLAUDE.md`(引擎/貢獻者版)**:重寫為架構說明——複製式安裝、`ENGINE_HOME`、CLI dispatcher、`find-brain` 解析、`_brain-template/` 結構、如何測試(見驗收),以及**「別把個人 notes commit 進引擎 repo」**的警告。

### H. README + package.json

- `README.md` 安裝流程改為:
  1. `git clone <repo> && cd brainstem && bash install.sh`(複製全域 skills + 引擎 + `brainstem` CLI;**裝完此 repo 可刪**)。
  2. `brainstem init ~/mybrain`(建議放私有處 / 設私有 git remote)。
  3. `cd ~/mybrain`,用 Claude Code 開啟說 hi → onboarding。
  - 「結構」段標明:引擎出 `skills/ check.mjs doctor.mjs init.mjs lib/ _brain-template/ VERSION install.sh`(`_templates/` 在 `_brain-template/` 內,非頂層);腦才有 `notes/ entities/ lens.md _index.md docs/drafts/`。
  - 加「升級」一句:重 clone + 重跑 install.sh;`brainstem --version` 查裝了哪版。
- `package.json`:**移除** `brain`/`doctor` scripts(引擎根不是腦,跑了也報「找不到腦」)。保留 `type:module` 與 `name`。引擎入口改為全域 `brainstem` CLI。

### I. 遷移(既有「clone 即腦」使用者;非選填)

若已有人把腦養在舊式 clone 根(根有 `.brainroot` + 個人 `notes/`):

1. 重跑 `install.sh`(裝全域引擎/CLI;不動他舊 clone 的內容)。
2. `brainstem use <舊clone路徑>`——舊 clone 仍含 `.brainroot`/`_templates`/`_index.md`/notes,可直接當腦續用;全域指標指向它即可。
3.(建議)把舊 clone 設為私有 repo、移出公開範圍。

README 加一段「從舊版遷移」。

### J. 本 session 善後

本次 onboarding 把工作目錄 `lens.md` 改成「已設定」版(移除 sentinel)。實作時:`_brain-template/lens.md` 取 **git HEAD 的未設定版**(`git show HEAD:lens.md`),引擎根 `lens.md` 隨 B 移除。淨效果是這次的 lens 編輯被丟棄、不進任何 commit——符合「引擎 repo 不含設定過的 lens」。

## 影響的檔案

| 檔案 | 動作 |
|---|---|
| `lib/find-brain.mjs` | 新增(BRAIN_DIR → cwd walk → 全域 config → error;可 import 亦可直跑當 `brainstem where`) |
| `lib/config.mjs` | 新增(讀/寫全域指標 `config.json`;`set <dir>` 供 `use`/`init`) |
| `check.mjs` | 改用 find-brain 定位 BRAIN |
| `doctor.mjs` | 改用 find-brain;加檢 `brainstem` 是否在 PATH;印當前 VERSION |
| `init.mjs` | 新增(`brainstem init` 實作) |
| `VERSION` | 新增(如 `0.1.0`) |
| `install.sh` | 改複製式;裝 ENGINE_HOME + `~/.local/bin/brainstem` + 複製 skills;PATH 提示 |
| `_brain-template/**` | 新增(seed notes/entity、未設定 lens、腦版 CLAUDE.md、_index、_templates note/entity、.gitignore、sources/docs 佔位) |
| `skills/brainstem-ingest/SKILL.md` | 定位改 `brainstem where`;`check.mjs`→`brainstem check`/`--dup` |
| `skills/brainstem-query/SKILL.md` | 定位改 `brainstem where`;加「問腦在哪 → `brainstem where`」 |
| `skills/brainstem-synthesize/SKILL.md` | 定位改 `brainstem where`;`check.mjs`→`brainstem check` |
| 根 `.brainroot`/`lens.md`/`log.md`/`_index.md`/`notes/`/`entities/`/`_templates/`/`sources/` | 移除(內容入 `_brain-template/`) |
| `bin/test-install.sh` | 改 symlink 斷言為「真實檔非 symlink」;加驗 `brainstem` CLI + VERSION |
| `bin/brain-root.sh` | 退役(由 `find-brain.mjs`/`brainstem where` 取代) |
| `bin/test-brain-root.sh`、`bin/test-doctor.sh` | retarget 到 `brainstem where`/`doctor` |
| 根 `CLAUDE.md` | 重寫為引擎/貢獻者版 |
| `README.md` | 改安裝/結構/升級/遷移 |
| `package.json` | 移除 `brain`/`doctor` scripts |

## 測試 / 驗收

1. **安裝**:`bash install.sh` 後 `which brainstem` 有值;`~/.claude/skills/brainstem-*` 是**真實檔非 symlink**(`test ! -L`);`~/.local/share/brainstem/VERSION` 存在;`brainstem --version` 印版號。
2. **init**:`brainstem init /tmp/tb` → `/tmp/tb` 含 `.brainroot`/`lens.md`(未設定)/`CLAUDE.md`/`_index.md`/`_templates/note.md`/seed notes/`sources/transcripts/`/`docs/drafts/`;全域 config 指向 `/tmp/tb`。
3. **doctor**:`cd /tmp/tb && brainstem doctor` → 報「lens 尚未設定」(紅,符合預期);填 lens 後 → 綠。
4. **check 對的是腦**:`cd /tmp/tb && brainstem check` 體檢 `/tmp/tb`(非引擎)。
5. **where / use**:任意 cwd 跑 `brainstem where` → 印 `/tmp/tb`(命中全域指標);`brainstem use /tmp/tb2`(先 init)→ 指標改;再 `where` 反映。
6. **query 轉達**:在 query skill 場景問「我腦在哪」→ 走 `brainstem where` 得 `/tmp/tb`。
7. **引擎根**:於引擎 repo 根跑 `brainstem check` → 報「找不到腦」exit 1(根無 `.brainroot`、cwd-walk 不命中;前提:未把全域指標指向它)。
8. **AC4 — repo 可刪**:`brainstem init /tmp/tb` 後,`mv` 或 `rm -rf` 引擎 repo,再 `cd /tmp/tb && brainstem check`、呼叫任一 skill → **仍正常**(全部已複製出 repo)。
9. **後門**:`BRAIN_DIR=/tmp/tb brainstem check`(在別處)→ 對 /tmp/tb 跑。
10. **init 防呆**:對已是腦的目錄 `init` → 拒絕;對非空無 `.brainroot` 目錄 → 拒絕。
11. **ingest 端到端**:在 `/tmp/tb` 餵一個來源 → 建頁、補 `_index.md`、`brainstem check --dup` 去重命中、`brainstem check` 0 孤島/0 斷鏈,全程不碰引擎 repo 路徑。
12. **引擎 repo `git status`**:不含任何個人 note / 設定過的 lens。

## 風險 / 取捨

- **複製 → 走味**:全域是靜態快照,`git pull` 不自動更新。緩解:`VERSION` + `brainstem --version`;升級 = 重 clone + 重跑 install.sh;`doctor` 可印當前 VERSION 供人工核對。(已知取捨,換得 AC4 與不鎖平台。)
- **`~/.local/bin` 未在 PATH(升級為承重風險)**:skills 改用 `brainstem where` 後,PATH 沒設好會讓**每次 skill 呼叫**`command not found`,直接威脅 AC1。緩解:install.sh 明顯提示(不自動改 rc)+ skill 片段先 `command -v brainstem` 探測並引導(F.1)+ `doctor` 增一檢:`brainstem` 是否在 PATH。
- **doctor 在非腦目錄的行為變了**:現行印「❌ .brainroot 不存在」走完清單;改用 find-brain 後會在解析階段就 exit 1。屬預期、無害,文件提一句即可。
- **兩個 CLAUDE.md 漂移**:腦版是唯一給使用者的真相,引擎版只談架構,職責不重疊以降風險。
- **全域指標失效**(腦被 `mv` 走):`find-brain` 偵測指標路徑已無 `.brainroot` → 當作未設定、報錯引導重 `brainstem use`。
- **單機單預設腦**:全域指標目前只存一顆預設腦;多腦靠 `cd` 進該腦(cwd-walk 優先於指標)或 `BRAIN_DIR`。多腦具名切換列為未來(YAGNI)。

## 實作切分(供 writing-plans)

範圍偏大(find-brain + config + dispatcher + init.mjs + `_brain-template/` + skill 編輯 + docs/migration),建議拆成有序子計畫,前者為後者的前置:

1. **引擎核心**:`lib/find-brain.mjs`(含直跑 CLI)、`lib/config.mjs`、`check.mjs`/`doctor.mjs` 改用 find-brain、複製式 `install.sh` + `~/.local/bin/brainstem` dispatcher + `VERSION`、修 `bin/` 測試。出口:`brainstem where/use/check/doctor/--version` 可跑、`bin/` 測試綠。
2. **範本 + init**:組 `_brain-template/`(含 seed、未設定 lens、_index、_templates、佔位)、`init.mjs`、`brainstem init` 串接 config.mjs。出口:`brainstem init` 出一顆可 doctor 的腦。
3. **skills 編輯**(用 `/writing-skills` 規範):三個 SKILL.md 定位改 `brainstem where`(含 PATH 探測)、兩處 `check.mjs`→`brainstem check`/`brainstem check --dup`、query 加問位置。出口:在 init 出的腦端到端 ingest 不碰 repo 路徑。
4. **文件 + 善後**:README、CLAUDE.md 拆引擎/腦版、遷移段、移除根腦檔與 `package.json` scripts。出口:引擎 repo `git status` 不含個人內容、AC4 刪 repo 測試過。

## 決策紀錄(供日後回溯)

- 複製+VERSION **勝過** Claude Code plugin:不鎖平台、乾淨達 AC4、主幹是 CLI、最簡;plugin 預留未來、不互斥。
- 位置介面 **CLI 為準 + query 轉達**:寫全域設定這種確定性操作 CLI 比 LLM-skill 可靠;自然語言查詢由 query skill 轉呼叫 CLI 補足。
- `_templates/lens.md` **不進範本**:無 skill 使用,未設定 lens 唯一真相 = `_brain-template/lens.md`,消除雙來源漂移。
