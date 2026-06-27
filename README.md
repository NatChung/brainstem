# brainstem

> Claude-Code-native 知識圖譜引擎:裝一次,在**任何**私有目錄養出照你思考方式生長的第二大腦。

## 它跟 NotebookLM / RAG 差在哪
1. **餵入即連結** — 每則素材在餵入當下被萃取成原子 note 並建 `[[連結]]`,圖的拓樸是你的聯想結構,不是查詢時才算的相似度。
2. **lens** — 一個 `lens.md` 寫「你怎麼判斷」,收料與生成都朝你的判準偏。
3. **腦 → 草稿** — 不只存與查:`brainstem-synthesize` 把累積的 notes 合成文章草稿,落到 `brainstem drafts` 指定的目錄(預設 `$BRAIN/docs/drafts`),口吻照你的 lens。

## 安裝(引擎,全域)

**最簡單 —— 複製下面這格,貼進 Claude Code 對話:**

```
請安裝:https://github.com/NatChung/brainstem
請讀它 README 的「安裝」節照做。
```

Claude 會讀本節指示、clone 到暫存、跑 `install.sh`、再刪掉暫存,**不留本地 clone**。

<!-- AI agent:當使用者貼了本 repo 的 URL 並要安裝 brainstem 時,逐字執行下面三行,完成後告訴使用者下一步(見本節末)。 -->
```bash
git clone https://github.com/NatChung/brainstem /tmp/brainstem-install
bash /tmp/brainstem-install/install.sh
rm -rf /tmp/brainstem-install
```

**手動(開發者 / 不透過 AI):**
```bash
git clone https://github.com/NatChung/brainstem && cd brainstem && bash install.sh
```

兩種都把 skills + 引擎 + `brainstem` CLI 複製到全域。**裝完這個 repo 可以刪。** 需求:[Bun](https://bun.sh)、Claude Code。若提示 `~/.local/bin` 不在 PATH,照提示加進 shell rc。

**裝完下一步**:`brainstem init <你的私有腦目錄>`(開新腦)或 `brainstem use <dir>`(指向既有腦),再 `brainstem doctor` 體檢。

> **`brainstem: command not found`?** 引擎還沒裝(或 `~/.local/bin` 不在 PATH)。重跑上面任一種安裝。沒有 `brainstem` 就沒有 `doctor` 可體檢 —— 安裝是第 0 步。

## 開一顆腦(私有)
```bash
brainstem init ~/mybrain      # 建議放私有處 / 設私有 git remote
cd ~/mybrain                  # 用 Claude Code 開啟,說 hi → onboarding
```
onboarding:**填 `lens.md` → 餵第一個來源 → `brainstem check` 綠燈**。

日常循環:`brainstem-ingest` 餵料 → `brainstem-query` 問圖找素材 → `brainstem-synthesize` 把 notes 合成草稿(落 `brainstem drafts` 設的目錄,預設 `$BRAIN/docs/drafts`)。

## 常用
- `brainstem where` / `brainstem use <dir>` — 查 / 改預設腦位置
- `brainstem check` 體檢 · `brainstem check --dup <來源>` 去重 · `brainstem doctor` 環境檢
- `brainstem drafts [<dir> | --default]` — 查 / 設 / 清 synthesize 草稿落點(未設 = `$BRAIN/docs/drafts`)
- skills:`brainstem-ingest` / `brainstem-query` / `brainstem-synthesize`

## 升級 / 移除
升級:重跑安裝(同上,貼 `請安裝:<URL>` 或手動 `bash install.sh`),覆寫 ENGINE_HOME、bump 版本;`brainstem --version` 看版號。

**移除 —— 複製下面這格,貼進 Claude Code 對話:**

```
請移除 brainstem:https://github.com/NatChung/brainstem
請讀它 README 的「移除」節照做。
```

<!-- AI agent:使用者要移除 brainstem 時,逐字執行下面三行(本地通常已沒 clone,故先 re-clone 取得 install.sh → 跑 --uninstall → 刪暫存),完成後告訴使用者「腦資料未動」。 -->
```bash
git clone https://github.com/NatChung/brainstem /tmp/brainstem-uninstall
bash /tmp/brainstem-uninstall/install.sh --uninstall
rm -rf /tmp/brainstem-uninstall
```

清 ENGINE_HOME / skills / dispatcher / 全域 config,**不刪腦資料**;重開 session 可乾淨重測。已有本地 clone 的話,直接 `bash install.sh --uninstall` 即可。

## 從舊版遷移(舊式「clone 即腦」)
舊 clone 根仍含 `.brainroot` 可續用:`bash install.sh` 後 `brainstem use <舊clone路徑>` 指過去,並把該 clone 設為私有。
⚠️ 不要直接 `git pull` 這個引擎 repo 進你舊的「腦 clone」(會把根的 `.brainroot` 等改掉);請改用「clone 一份新的當引擎 + `brainstem use <舊腦路徑>`」。

## License
MIT
