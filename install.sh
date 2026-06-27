#!/usr/bin/env bash
# 把 skills/* symlink 進 ~/.claude/skills/,可選前綴。idempotent。
set -euo pipefail
PREFIX="${1:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"
mkdir -p "$DEST"
for s in ingest query synthesize; do
  name="${PREFIX:+${PREFIX}-}$s"
  ln -sfn "$ROOT/skills/$s" "$DEST/$name"
  echo "linked $DEST/$name → $ROOT/skills/$s"
done
