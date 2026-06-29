#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/skills/brainstem-ingest/SKILL.md"

# 深 ingest 段落存在
grep -q 'GitHub repo 深 ingest' "$F" || { echo "FAIL: missing GitHub deep-ingest section"; exit 1; }
# canonical URL 形式 + 正規化規則
grep -q 'https://github.com/<owner>/<repo>' "$F" || { echo "FAIL: missing canonical repo URL form"; exit 1; }
grep -q 'lowercase' "$F" || { echo "FAIL: missing normalization (lowercase)"; exit 1; }
grep -q '\.git' "$F" || { echo "FAIL: missing normalization (strip .git)"; exit 1; }
# clone 到 temp(shallow depth + scratchpad 指引)
grep -q 'git clone --depth 100' "$F" || { echo "FAIL: missing shallow clone"; exit 1; }
grep -q 'scratchpad' "$F" || { echo "FAIL: missing scratchpad temp guidance"; exit 1; }
# codegraph CLI 而非 MCP
grep -q 'codegraph init' "$F" || { echo "FAIL: missing codegraph CLI init"; exit 1; }
grep -q 'codegraph files -p' "$F" || { echo "FAIL: missing codegraph CLI -p path flag"; exit 1; }
! grep -q 'codegraph_' "$F" || { echo "FAIL: must not reference codegraph MCP tools"; exit 1; }
# 巨倉規模閘
grep -q '5000' "$F" || { echo "FAIL: missing huge-repo size guard"; exit 1; }
# entity front-matter 欄位齊全
for field in repo_url default_branch last_commit last_ingested; do
  grep -q "$field" "$F" || { echo "FAIL: missing front-matter field $field"; exit 1; }
done
# 增量 deepen 修正(=N 或 unshallow,非裸 --deepen)
grep -qE 'deepen=[0-9]|--unshallow' "$F" || { echo "FAIL: missing fetch --deepen=N/--unshallow"; exit 1; }
# 增量再餵節
grep -q '增量再餵' "$F" || { echo "FAIL: missing incremental re-ingest section"; exit 1; }
echo "PASS"
