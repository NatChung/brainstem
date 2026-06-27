#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  F="$ROOT/skills/$s/SKILL.md"
  grep -q 'brainstem where' "$F" || { echo "FAIL: $s missing 'brainstem where'"; exit 1; }
  grep -q 'command -v brainstem' "$F" || { echo "FAIL: $s missing PATH probe"; exit 1; }
  ! grep -q '\$BRAIN/check.mjs' "$F" || { echo "FAIL: $s still calls \$BRAIN/check.mjs"; exit 1; }
  ! grep -q 'while \[ "\$d" != / \]' "$F" || { echo "FAIL: $s still has inline brainroot walk"; exit 1; }
done
grep -q 'brainstem check --dup' "$ROOT/skills/brainstem-ingest/SKILL.md" || { echo "FAIL: ingest dedup not rewired"; exit 1; }
grep -q 'brainstem where' "$ROOT/skills/brainstem-query/SKILL.md" || { echo "FAIL: query 'where' answer missing"; exit 1; }
echo "PASS"
