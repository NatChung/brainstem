#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 子目錄內應解析到 repo 根
cd "$ROOT/notes"
OUT="$(bash "$ROOT/bin/brain-root.sh")"
[ "$OUT" = "$ROOT" ] || { echo "FAIL: got '$OUT' want '$ROOT'"; exit 1; }
# repo 外(/tmp)應失敗
cd /tmp
if bash "$ROOT/bin/brain-root.sh" >/dev/null 2>&1; then echo "FAIL: should error outside brain"; exit 1; fi
echo "PASS"
