#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"; printf '# lens\n- x\n' > "$B/lens.md"
CFG="$(mktemp -d)"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"; mkdir -p "$D"

# doctor:未 pin → 顯示「預設,跟腦」
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/doctor.mjs" || true)"
echo "$OUT" | grep -q "drafts: $B/docs/drafts" || { echo "FAIL: doctor should show default drafts"; echo "$OUT"; exit 1; }

# doctor:pin → 顯示 pinned
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/doctor.mjs" || true)"
echo "$OUT" | grep -q "drafts: $D(pinned)" || { echo "FAIL: doctor should show pinned drafts"; echo "$OUT"; exit 1; }

# init:draftsDir 已 pin(且 config 無 brain key)→ init 仍設 brain key,且輸出含提醒
NBP="$(mktemp -d)"; NB="$NBP/nb"
OUT="$(XDG_CONFIG_HOME="$CFG" bun "$ROOT/init.mjs" "$NB")"
echo "$OUT" | grep -q "不隨腦切換" || { echo "FAIL: init should warn when drafts pinned"; echo "$OUT"; exit 1; }
grep -q '"brain"' "$CFG/brainstem/config.json" || { echo "FAIL: init should set brain key even when config already has draftsDir"; exit 1; }

rm -rf "$B" "$CFG" "$(dirname "$D")" "$NBP"
echo "PASS"
