# brainstem

> Claude-Code-native 知識圖譜引擎:裝一次,在**任何**私有目錄養出照你思考方式生長的第二大腦。

## 它跟 NotebookLM / RAG 差在哪
1. **餵入即連結** — 每則素材在餵入當下被萃取成原子 note 並建 `[[連結]]`,圖的拓樸是你的聯想結構,不是查詢時才算的相似度。
2. **lens** — 一個 `lens.md` 寫「你怎麼判斷」,收料與生成都朝你的判準偏。

## 安裝(引擎,全域)
```bash
git clone <repo> && cd brainstem && bash install.sh
```
複製 skills + 引擎 + `brainstem` CLI 到全域。**裝完這個 repo 可以刪。** 需求:[Bun](https://bun.sh)、Claude Code。若提示 `~/.local/bin` 不在 PATH,照提示加進 shell rc。

## 開一顆腦(私有)
```bash
brainstem init ~/mybrain      # 建議放私有處 / 設私有 git remote
cd ~/mybrain                  # 用 Claude Code 開啟,說 hi → onboarding
```
onboarding:**填 `lens.md` → 餵第一個來源 → `brainstem check` 綠燈**。

## 常用
- `brainstem where` / `brainstem use <dir>` — 查 / 改預設腦位置
- `brainstem check` 體檢 · `brainstem check --dup <來源>` 去重 · `brainstem doctor` 環境檢
- skills:`brainstem-ingest` / `brainstem-query` / `brainstem-synthesize`

## 升級
重 clone + 重跑 `install.sh`;`brainstem --version` 看版號。

## 從舊版遷移(舊式「clone 即腦」)
舊 clone 根仍含 `.brainroot` 可續用:`bash install.sh` 後 `brainstem use <舊clone路徑>` 指過去,並把該 clone 設為私有。
⚠️ 不要直接 `git pull` 這個引擎 repo 進你舊的「腦 clone」(會把根的 `.brainroot` 等改掉);請改用「clone 一份新的當引擎 + `brainstem use <舊腦路徑>`」。

## License
MIT
