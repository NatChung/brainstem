#!/usr/bin/env bash
# 複製式全域安裝:引擎 → ENGINE_HOME、skills → ~/.claude/skills、CLI → ~/.local/bin。
# idempotent = 升級。裝完此 repo 可刪。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"

OLD="$(cat "$ENGINE_HOME/VERSION" 2>/dev/null || echo none)"
mkdir -p "$ENGINE_HOME" "$SKILLS" "$BIN"

# 引擎 runtime(先清舊 lib/_brain-template 再複製,避免殘檔)
rm -rf "$ENGINE_HOME/lib" "$ENGINE_HOME/_brain-template"
cp -R "$ROOT/check.mjs" "$ROOT/doctor.mjs" "$ROOT/init.mjs" \
      "$ROOT/lib" "$ROOT/_brain-template" "$ROOT/VERSION" "$ENGINE_HOME/"

# skills(真實檔、非 symlink)
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  rm -rf "$SKILLS/$s"
  cp -R "$ROOT/skills/$s" "$SKILLS/$s"
  echo "copied $SKILLS/$s"
done

# CLI dispatcher
cp "$ROOT/bin/brainstem" "$BIN/brainstem"
chmod +x "$BIN/brainstem"

NEW="$(cat "$ROOT/VERSION")"
echo "brainstem $OLD → $NEW 已安裝(engine: $ENGINE_HOME)"
echo "下一步:brainstem init <你的私有腦目錄>"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "⚠ $BIN 不在 PATH — 加進 shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
