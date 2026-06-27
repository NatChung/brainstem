#!/usr/bin/env bash
# 從 cwd 向上找最近含 .brainroot 的祖先目錄,印其絕對路徑;找不到 exit 1。
d="$PWD"
while [ "$d" != / ] && [ ! -e "$d/.brainroot" ]; do d="$(dirname "$d")"; done
[ -e "$d/.brainroot" ] || { echo "找不到 .brainroot — 請先 cd 進你的 brain repo。" >&2; exit 1; }
printf '%s' "$d"
