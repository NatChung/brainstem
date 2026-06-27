#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"; mkdir -p "$B/notes" "$B/entities"
CFG="$(mktemp -d)"
D="$(cd "$(mktemp -d)" && pwd -P)/drafts"; mkdir -p "$D"; : > "$D/a.md"; : > "$D/b.md"
mkdir -p "$CFG/brainstem"; printf '{ "draftsDir": "%s" }\n' "$D" > "$CFG/brainstem/config.json"
OUT="$(BRAIN_DIR="$B" XDG_CONFIG_HOME="$CFG" bun "$ROOT/check.mjs" || true)"
echo "$OUT" | grep -q "drafts:2" || { echo "FAIL: check should count 2 drafts from pinned dir"; echo "$OUT"; exit 1; }
rm -rf "$B" "$CFG" "$(dirname "$D")"
echo "PASS"
