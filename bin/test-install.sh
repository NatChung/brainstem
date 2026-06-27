#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP" XDG_DATA_HOME="$TMP/share" XDG_CONFIG_HOME="$TMP/config"
# 裝兩次(idempotent)
bash "$ROOT/install.sh" >/dev/null
bash "$ROOT/install.sh" >/dev/null
# skills 是真實檔、非 symlink
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  D="$TMP/.claude/skills/$s"
  [ -e "$D" ] && [ ! -L "$D" ] || { echo "FAIL: $s not a real dir"; exit 1; }
  [ -f "$D/SKILL.md" ] || { echo "FAIL: $s/SKILL.md missing"; exit 1; }
done
# 引擎複製進 ENGINE_HOME
for f in check.mjs doctor.mjs init.mjs lib/find-brain.mjs lib/config.mjs _brain-template/.brainroot VERSION; do
  [ -e "$TMP/share/brainstem/$f" ] || { echo "FAIL: ENGINE_HOME missing $f"; exit 1; }
done
# CLI dispatcher 可跑
[ -x "$TMP/.local/bin/brainstem" ] || { echo "FAIL: brainstem CLI missing"; exit 1; }
"$TMP/.local/bin/brainstem" --version | grep -q . || { echo "FAIL: --version empty"; exit 1; }
echo "PASS"
