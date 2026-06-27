#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$ROOT/lib/config.mjs"
FB="$ROOT/lib/find-brain.mjs"
CFGHOME="$(mktemp -d)"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"

# set 寫入指標,且 find-brain 隨後解析得到它
XDG_CONFIG_HOME="$CFGHOME" bun "$CFG" set "$B" >/dev/null
grep -q "$B" "$CFGHOME/brainstem/config.json" || { echo "FAIL: pointer not written"; exit 1; }
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFGHOME" bun "$FB")"
[ "$OUT" = "$B" ] || { echo "FAIL: resolve got '$OUT'"; exit 1; }

# 拒絕非腦目錄
NOPE="$(mktemp -d)"
if XDG_CONFIG_HOME="$CFGHOME" bun "$CFG" set "$NOPE" >/dev/null 2>&1; then echo "FAIL: should reject non-brain"; exit 1; fi

rm -rf "$CFGHOME" "$B" "$NOPE"
echo "PASS"
