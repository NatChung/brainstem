#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FB="$ROOT/lib/find-brain.mjs"

# 1. BRAIN_DIR 直接採信(即使無 .brainroot)
D1="$(mktemp -d)"
OUT="$(BRAIN_DIR="$D1" bun "$FB")"; [ "$OUT" = "$D1" ] || { echo "FAIL: BRAIN_DIR"; exit 1; }

# 2. cwd 上行找 .brainroot(用 pwd -P 正規化,避免 TMPDIR 經 symlink)
B="$(cd "$(mktemp -d)" && pwd -P)"; : > "$B/.brainroot"; mkdir -p "$B/sub"
OUT="$(cd "$B/sub" && env -u BRAIN_DIR bun "$FB")"; [ "$OUT" = "$B" ] || { echo "FAIL: cwd-walk got '$OUT'"; exit 1; }

# 3. 全域指標(指向含 .brainroot 的腦)
CFGHOME="$(mktemp -d)"; mkdir -p "$CFGHOME/brainstem"
printf '{ "brain": "%s" }\n' "$B" > "$CFGHOME/brainstem/config.json"
OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$CFGHOME" bun "$FB")"
[ "$OUT" = "$B" ] || { echo "FAIL: config pointer got '$OUT'"; exit 1; }

# 4. 都沒有 → exit 1 + 訊息走 stderr(stdout 空)
EMPTY="$(mktemp -d)"
if OUT="$(cd /tmp && env -u BRAIN_DIR XDG_CONFIG_HOME="$EMPTY" bun "$FB" 2>/dev/null)"; then echo "FAIL: should exit 1"; exit 1; fi
[ -z "${OUT:-}" ] || { echo "FAIL: path should not go to stdout"; exit 1; }

rm -rf "$D1" "$B" "$CFGHOME" "$EMPTY"
echo "PASS"
