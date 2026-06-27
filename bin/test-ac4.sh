#!/usr/bin/env bash
# 裝進臨時 HOME,刪掉 repo 副本後,brainstem 仍能 init + check。
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/repo"; cp -R "$SRC" "$WORK"
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/home/.local/share" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/home/.local/bin:$PATH"
mkdir -p "$HOME"
bash "$WORK/install.sh" >/dev/null
rm -rf "$WORK"                      # 刪掉引擎 repo
brainstem init "$TMP/brain" >/dev/null
( cd "$TMP/brain" && brainstem check >/dev/null ) || { echo "FAIL: check broke after repo deleted"; exit 1; }
brainstem where | grep -q "$TMP/brain" || { echo "FAIL: where broke after repo deleted"; exit 1; }
echo "PASS"
