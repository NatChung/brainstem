#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP" XDG_DATA_HOME="$TMP/share" XDG_CONFIG_HOME="$TMP/config"

# 裝
bash "$ROOT/install.sh" >/dev/null
# 模擬「已設過腦」:手動塞 config.json(install 不會產生它)
mkdir -p "$TMP/config/brainstem"
printf '{"brain":"%s/somebrain"}\n' "$TMP" > "$TMP/config/brainstem/config.json"

# 斷言四類目標都在
[ -f "$TMP/share/brainstem/VERSION" ] || { echo "FAIL: ENGINE_HOME missing before uninstall"; exit 1; }
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  [ -f "$TMP/.claude/skills/$s/SKILL.md" ] || { echo "FAIL: skill $s missing before uninstall"; exit 1; }
done
[ -x "$TMP/.local/bin/brainstem" ] || { echo "FAIL: CLI missing before uninstall"; exit 1; }
[ -f "$TMP/config/brainstem/config.json" ] || { echo "FAIL: config missing before uninstall"; exit 1; }

# uninstall
bash "$ROOT/install.sh" --uninstall >/dev/null

# 斷言四類目標全不存在(config 連整個目錄)
[ ! -e "$TMP/share/brainstem" ]      || { echo "FAIL: ENGINE_HOME still present"; exit 1; }
for s in brainstem-ingest brainstem-query brainstem-synthesize; do
  [ ! -e "$TMP/.claude/skills/$s" ]  || { echo "FAIL: skill $s still present"; exit 1; }
done
[ ! -e "$TMP/.local/bin/brainstem" ] || { echo "FAIL: CLI still present"; exit 1; }
[ ! -e "$TMP/config/brainstem" ]     || { echo "FAIL: config dir still present"; exit 1; }

# idempotent:再跑一次仍 exit 0
bash "$ROOT/install.sh" --uninstall >/dev/null || { echo "FAIL: second uninstall not idempotent"; exit 1; }

echo "PASS"
