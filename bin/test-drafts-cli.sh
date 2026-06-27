#!/usr/bin/env bash
# 臨時安裝後端到端驗 drafts 子命令(同 test-install.sh 模式)。
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/home/.local/share" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/home/.local/bin:$PATH"
mkdir -p "$HOME"
bash "$SRC/install.sh" >/dev/null

D="$TMP/blog/content"
brainstem drafts "$D" >/dev/null            # set
[ -d "$D" ] || { echo "FAIL: drafts <dir> should mkdir"; exit 1; }
OUT="$(brainstem drafts)"                    # get(免腦,pinned)
[ "$OUT" = "$D" ] || { echo "FAIL: drafts get got '$OUT'"; exit 1; }
if brainstem drafts a b >/dev/null 2>&1; then echo "FAIL: extra args should error"; exit 1; fi

# 用 brainstem use 設腦(T2 的 read-merge-write,T3 當下就可用;不依賴 T5 的 init 修正)
mkdir -p "$TMP/brain" && : > "$TMP/brain/.brainroot"
brainstem use "$TMP/brain" >/dev/null        # read-merge-write → {draftsDir, brain} 都在
brainstem drafts --default >/dev/null        # 清 draftsDir → {brain}
OUT="$(brainstem drafts)"
[ "$OUT" = "$TMP/brain/docs/drafts" ] || { echo "FAIL: after --default should follow brain, got '$OUT'"; exit 1; }
echo "PASS"
