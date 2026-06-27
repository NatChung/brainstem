#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/doctor.mjs"
# A: 已設定 → exit 0
A="$(mktemp -d)"; : > "$A/.brainroot"; printf '# lens\n- 判準\n' > "$A/lens.md"
BRAIN_DIR="$A" bun "$DOC" >/dev/null || { echo "FAIL: configured should exit 0"; exit 1; }
# B: lens 未設定(含 sentinel)→ exit 1
B="$(mktemp -d)"; : > "$B/.brainroot"; printf '<!-- LENS_UNCONFIGURED -->\n# lens\n' > "$B/lens.md"
if BRAIN_DIR="$B" bun "$DOC" >/dev/null; then echo "FAIL: unconfigured lens should exit 1"; exit 1; fi
# C: 無 .brainroot → exit 1
C="$(mktemp -d)"; printf '# lens\n' > "$C/lens.md"
if BRAIN_DIR="$C" bun "$DOC" >/dev/null; then echo "FAIL: no brainroot should exit 1"; exit 1; fi
rm -rf "$A" "$B" "$C"
echo "PASS"
