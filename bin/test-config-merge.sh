#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFGJS="$ROOT/lib/config.mjs"
CFG="$(mktemp -d)"; cfgfile="$CFG/brainstem/config.json"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"

# set-drafts:建夾 + 寫 key
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
[ -d "$D" ] || { echo "FAIL: set-drafts should mkdir -p"; exit 1; }
grep -q '"draftsDir"' "$cfgfile" || { echo "FAIL: draftsDir not written"; exit 1; }

# 反序(Critical 回歸):set-drafts 在前,再 set 腦 → 兩個 key 都在
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B" >/dev/null
grep -q '"brain"' "$cfgfile" || { echo "FAIL: brain not written"; exit 1; }
grep -q '"draftsDir"' "$cfgfile" || { echo "FAIL: setBrain clobbered draftsDir"; exit 1; }

# 反向:先 set 腦再 set-drafts → 兩個都在
rm -f "$cfgfile"
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B" >/dev/null
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
{ grep -q '"brain"' "$cfgfile" && grep -q '"draftsDir"' "$cfgfile"; } || { echo "FAIL: set-drafts clobbered brain"; exit 1; }

# unset-drafts:draftsDir 消失、brain 保留
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" unset-drafts >/dev/null
grep -q '"draftsDir"' "$cfgfile" && { echo "FAIL: draftsDir not removed"; exit 1; }
grep -q '"brain"' "$cfgfile" || { echo "FAIL: unset-drafts clobbered brain"; exit 1; }

# setBrain pinned 提醒
XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set-drafts "$D" >/dev/null
OUT="$(XDG_CONFIG_HOME="$CFG" bun "$CFGJS" set "$B")"
echo "$OUT" | grep -q "不隨腦切換" || { echo "FAIL: setBrain should warn when drafts pinned"; exit 1; }

rm -rf "$CFG" "$B" "$(dirname "$D")"
echo "PASS"
