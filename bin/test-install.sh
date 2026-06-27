#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
# 裝兩次(idempotent 不報錯)
HOME="$TMPHOME" bash "$ROOT/install.sh"
HOME="$TMPHOME" bash "$ROOT/install.sh"
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  [ -L "$TMPHOME/.claude/skills/$s" ] || { echo "FAIL: missing $s"; exit 1; }
done
echo "PASS"
