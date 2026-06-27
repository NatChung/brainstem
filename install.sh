#!/usr/bin/env bash
# 把 skills/* symlink 進 ~/.claude/skills/。idempotent。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"
mkdir -p "$DEST"
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  ln -sfn "$ROOT/skills/$s" "$DEST/$s"
  echo "linked $DEST/$s → $ROOT/skills/$s"
done
