#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

echo "== Swift Release 契约测试 =="
cpu_count="${LUTCALC_CPU_COUNT:-$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 1)}"
swift_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-fast-swift.XXXXXX")"
node_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-fast-node.XXXXXX")"
trap 'rm -f "$swift_log" "$node_log"' EXIT
swift test -c release --package-path Native/Packages/LUTKit \
  --parallel \
  --jobs "${LUTCALC_SWIFT_JOBS:-$cpu_count}" \
  --num-workers "${LUTCALC_TEST_WORKERS:-$cpu_count}" >"$swift_log" 2>&1 &
swift_pid=$!
echo "== 既有 Node 契约测试 =="
node --test tests/*.test.js >"$node_log" 2>&1 &
node_pid=$!
status=0
wait "$swift_pid" || status=1
wait "$node_pid" || status=1
cat "$swift_log" "$node_log"
if (( status != 0 )); then
  exit "$status"
fi
echo "快速原生验证通过。该入口不替代完整数值、平台和发布验收。"
