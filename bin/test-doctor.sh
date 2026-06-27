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
# D: lens 未設定時,輸出含可操作引導(對話式 onboarding 的「全用推薦」捷徑 + lens 路徑)
D="$(mktemp -d)"; : > "$D/.brainroot"; printf '<!-- LENS_UNCONFIGURED -->\n# lens\n' > "$D/lens.md"
OUT="$(BRAIN_DIR="$D" bun "$DOC" 2>&1 || true)"
case "$OUT" in *全用推薦*) ;; *) echo "FAIL: unconfigured lens should print onboarding hint (全用推薦)"; exit 1;; esac
case "$OUT" in *"$D/lens.md"*) ;; *) echo "FAIL: unconfigured lens hint should name the lens.md path"; exit 1;; esac
rm -rf "$A" "$B" "$C" "$D"
echo "PASS"
