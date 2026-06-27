#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPHOME="$(mktemp -d)"
# 無前綴
HOME="$TMPHOME" bash "$ROOT/install.sh"
for s in ingest query synthesize; do
  [ -L "$TMPHOME/.claude/skills/$s" ] || { echo "FAIL: missing $s"; exit 1; }
done
# 帶前綴 + idempotent(重跑不報錯)
HOME="$TMPHOME" bash "$ROOT/install.sh" test
HOME="$TMPHOME" bash "$ROOT/install.sh" test
for s in ingest query synthesize; do
  [ -L "$TMPHOME/.claude/skills/test-$s" ] || { echo "FAIL: missing test-$s"; exit 1; }
done
rm -rf "$TMPHOME"
echo "PASS"
