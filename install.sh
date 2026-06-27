#!/usr/bin/env bash
# 複製式全域安裝:引擎 → ENGINE_HOME、skills → ~/.claude/skills、CLI → ~/.local/bin。
# idempotent = 升級。裝完此 repo 可刪。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ENGINE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/brainstem"
SKILLS="$HOME/.claude/skills"
BIN="$HOME/.local/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/brainstem"

# 只刪結尾像 brainstem 的固定引擎路徑(白名單只驗後綴,擋離譜空值)
safe_rm() {
  case "$1" in
    */brainstem|*/brainstem-ingest|*/brainstem-query|*/brainstem-synthesize) rm -rf "$1" ;;
    *) echo "防呆:拒刪非預期路徑 $1" >&2; exit 1 ;;
  esac
}

do_uninstall() {
  for p in "$ENGINE_HOME" \
           "$SKILLS/brainstem-ingest" "$SKILLS/brainstem-query" "$SKILLS/brainstem-synthesize" \
           "$BIN/brainstem" \
           "$CONFIG_HOME"; do
    if [ -e "$p" ]; then safe_rm "$p"; echo "removed  $p"
    else echo "skip     $p(不存在)"; fi
  done
  echo
  echo "brainstem 引擎已移除。腦資料未動。"
  echo "重裝:bash install.sh"
  echo "腦仍在,重指:brainstem use <你的腦目錄>"
  echo "若重測仍偵測到腦:檢查是否 export 了 \$BRAIN_DIR,或換到非腦目錄再開 session。"
}

case "${1:-}" in
  "")          : ;;            # 無參數 = 安裝(以下原有流程)
  --uninstall) do_uninstall; exit 0 ;;
  *)           echo "用法:install.sh [--uninstall]" >&2; exit 1 ;;
esac

OLD="$(cat "$ENGINE_HOME/VERSION" 2>/dev/null || echo none)"
mkdir -p "$ENGINE_HOME" "$SKILLS" "$BIN"

# 引擎 runtime(先清舊 lib/_brain-template 再複製,避免殘檔)
rm -rf "$ENGINE_HOME/lib" "$ENGINE_HOME/_brain-template"
cp -R "$ROOT/check.mjs" "$ROOT/doctor.mjs" "$ROOT/init.mjs" \
      "$ROOT/lib" "$ROOT/_brain-template" "$ROOT/VERSION" "$ENGINE_HOME/"

# skills(真實檔、非 symlink)
# ⚠ 新增 skill 時,此清單要同步四處:本迴圈 / install.sh do_uninstall / bin/test-install.sh / bin/test-uninstall.sh
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
