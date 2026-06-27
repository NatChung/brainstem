#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/init.mjs"
CFGHOME="$(mktemp -d)"
TB="$(mktemp -d)/tb"   # 不存在的子目錄

# init 建腦
XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$TB" >/dev/null
for f in .brainroot lens.md CLAUDE.md _index.md _templates/note.md notes/atomic-note-one-idea.md sources/transcripts docs/drafts; do
  [ -e "$TB/$f" ] || { echo "FAIL: init missing $f"; exit 1; }
done
grep -q "LENS_UNCONFIGURED" "$TB/lens.md" || { echo "FAIL: lens should be unconfigured"; exit 1; }
# 指標未設定 → init 設成這顆
grep -q "$TB" "$CFGHOME/brainstem/config.json" || { echo "FAIL: pointer not set on first init"; exit 1; }

# 對已是腦的目錄 init → 拒絕
if XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$TB" >/dev/null 2>&1; then echo "FAIL: should refuse existing brain"; exit 1; fi

# 對非空非腦目錄 init → 拒絕
NE="$(mktemp -d)"; : > "$NE/x"
if XDG_CONFIG_HOME="$CFGHOME" bun "$INIT" "$NE" >/dev/null 2>&1; then echo "FAIL: should refuse non-empty"; exit 1; fi

rm -rf "$CFGHOME" "$TB" "$NE"
echo "PASS"
