# brainstem — 引擎開發(貢獻者文件)

> 這個 repo 是**引擎**,不是一顆腦。使用者的私有腦(notes/lens/`.brainroot`)住在別處,由 `brainstem init` 建立。
> **別把任何個人 note / 設定過的 lens commit 進這個公開 repo。**

## 架構
- **安裝 = 複製**(非 symlink、非 plugin):`install.sh` 把引擎複製到 `ENGINE_HOME`(`${XDG_DATA_HOME:-~/.local/share}/brainstem`)、skills 複製到 `~/.claude/skills/`、dispatcher 到 `~/.local/bin/brainstem`。裝完 repo 可刪。
- **腦解析**:`lib/find-brain.mjs` —— `BRAIN_DIR` → cwd 上行 `.brainroot` → 全域指標 `${XDG_CONFIG_HOME:-~/.config}/brainstem/config.json` → error。`check.mjs`/`doctor.mjs`/`brainstem where` 共用它。
- **CLI**:`bin/brainstem`(POSIX 分派)→ `where|use|init|check|doctor|--version`。
- **新腦骨架**:`_brain-template/`(由 `init.mjs` 複製)。

## 本機測試
```bash
bash bin/test-find-brain.sh
bash bin/test-config.sh
bash bin/test-doctor.sh
bash bin/test-init.sh
bash bin/test-install.sh
bash bin/test-skills-wiring.sh
bash bin/test-ac4.sh
# 手動冒煙:
bash install.sh && brainstem init /tmp/demo-brain && (cd /tmp/demo-brain && brainstem doctor)
```

## 升級
重 clone 最新 repo + 重跑 `install.sh`(覆寫 ENGINE_HOME、bump VERSION)。`brainstem --version` 看裝了哪版。

## 語言政策
- 本檔與 skill 指令用中文;使用者 notes/lens 語言自訂。
