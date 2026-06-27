#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DR="$ROOT/lib/drafts.mjs"

# 1. 未設 draftsDir → $BRAIN/docs/drafts(經 BRAIN_DIR)
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"
CFG="$(mktemp -d)"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$B/docs/drafts" ] || { echo "FAIL: unset should follow brain, got '$OUT'"; exit 1; }

# 5a. 設了 draftsDir → 回它,且免腦也成立
D="$(cd "$(mktemp -d)" && pwd -P)/out"
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$D" ] || { echo "FAIL: pinned should win without brain, got '$OUT'"; exit 1; }

# 5b. pinned 蓋過腦
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$D" ] || { echo "FAIL: pinned should override brain, got '$OUT'"; exit 1; }

# 6. 未設且無腦 → stderr + exit 1,stdout 空
EMPTY="$(mktemp -d)"
if OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$EMPTY" bun "$DR" 2>/dev/null)"; then echo "FAIL: no brain+unset should exit 1"; exit 1; fi
[ -z "${OUT:-}" ] || { echo "FAIL: should not print path on error"; exit 1; }

# 壞檔當未設 → 回退到腦
printf 'not json{' > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$DR")"
[ "$OUT" = "$B/docs/drafts" ] || { echo "FAIL: corrupt config should be treated as unset, got '$OUT'"; exit 1; }

rm -rf "$B" "$CFG" "$EMPTY" "$(dirname "$D")"
echo "PASS"
