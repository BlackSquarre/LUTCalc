#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"

cpu_count="${LUTCALC_CPU_COUNT:-$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 1)}"
swift_test_pid=""
swift_test_log=""
if [[ "${LUTCALC_RUN_SWIFT_TEST:-0}" == "1" ]]; then
  swift_test_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-release-swift-test.XXXXXX")"
  swift test -c release --package-path Native/Packages/LUTKit \
    --parallel --jobs "${LUTCALC_SWIFT_JOBS:-$cpu_count}" \
    --num-workers "${LUTCALC_TEST_WORKERS:-$cpu_count}" >"$swift_test_log" 2>&1 &
  swift_test_pid=$!
fi
cleanup() {
  if [[ -n "$swift_test_pid" ]]; then
    kill "$swift_test_pid" 2>/dev/null || true
  fi
  [[ -z "$swift_test_log" ]] || rm -f "$swift_test_log"
}
trap cleanup EXIT

cat <<'CHECKS' | python3 tools/native-validation/run-command-batch.py --workers "${LUTCALC_VALIDATION_WORKERS:-$cpu_count}"
python3 tools/native-validation/audit-native-sources.py
node tools/native-validation/generate-tricubic-legacy-reference.js --check
node tools/native-validation/generate-cubic1d-legacy-reference.js --check
node tools/native-validation/generate-asccdl-legacy-reference.js --check
python3 tools/native-validation/generate-asccdl-independent-reference.py --check
node tools/native-validation/generate-sdr-saturation-legacy-reference.js --check
node tools/native-validation/generate-sdr-saturation-legacy-pipeline.js --check
python3 tools/native-validation/generate-sdr-saturation-independent-reference.py --check
node tools/native-validation/generate-multitone-legacy-reference.js --check
node tools/native-validation/generate-multitone-legacy-pipeline.js --check
python3 tools/native-validation/generate-multitone-independent-reference.py --check
python3 tools/native-validation/generate-multitone-independent-grid.py --check
node tools/native-validation/generate-black-gamma-legacy-reference.js --check
node tools/native-validation/generate-black-gamma-legacy-pipeline.js --check
python3 tools/native-validation/generate-black-gamma-independent-reference.py --check
node tools/native-validation/generate-output-code-units-legacy-reference.js --check
python3 tools/native-validation/generate-output-code-units-independent-reference.py --check
node tools/native-validation/generate-display-conversion-legacy-reference.js --check
node tools/native-validation/generate-display-conversion-legacy-pipeline.js --linear --check
node tools/native-validation/generate-display-conversion-legacy-pipeline.js --check
python3 tools/native-validation/generate-display-conversion-independent-reference.py --check
python3 tools/native-validation/generate-display-conversion-export-reference.py --check
node tools/native-validation/generate-exposure-batch-legacy-reference.js --check
python3 tools/native-validation/generate-exposure-batch-independent-reference.py --check
node tools/native-validation/generate-final-output-legacy-reference.js --check
node tools/native-validation/generate-final-output-legacy-pipeline.js --linear --check
node tools/native-validation/generate-final-output-legacy-pipeline.js --check
python3 tools/native-validation/generate-final-output-independent-reference.py --check
node tools/native-validation/generate-false-colour-legacy-reference.js --check
node tools/native-validation/generate-false-colour-legacy-pipeline.js --linear --check
node tools/native-validation/generate-false-colour-legacy-pipeline.js --check
python3 tools/native-validation/generate-false-colour-independent-reference.py --check
python3 tools/native-validation/audit-false-colour-threshold-boundaries.py --check
node tools/native-validation/generate-gamut-limiter-legacy-reference.js --check
node tools/native-validation/generate-gamut-limiter-legacy-pipeline.js --linear --check
node tools/native-validation/generate-gamut-limiter-legacy-pipeline.js --check
python3 tools/native-validation/generate-gamut-limiter-independent-reference.py --check
node tools/native-validation/generate-highlight-gamut-legacy-reference.js --check
node tools/native-validation/generate-highlight-gamut-legacy-pipeline.js --check
python3 tools/native-validation/generate-highlight-gamut-independent-reference.py --check
node tools/native-validation/generate-knee-legacy-reference.js --check
node tools/native-validation/generate-knee-legacy-pipeline.js --check
python3 tools/native-validation/generate-knee-independent-reference.py --check
python3 tools/native-validation/audit-knee-legacy-derivatives.py --check
node tools/native-validation/generate-black-highlight-legacy-reference.js --check
node tools/native-validation/generate-black-highlight-legacy-pipeline.js --check
python3 tools/native-validation/generate-black-highlight-independent-reference.py --check
node tools/native-validation/inspect-legacy-risks.js
node tools/native-validation/verify-contract-fixtures.js
python3 tools/native-validation/verify-rec709-fixtures.py
python3 tools/native-validation/generate-slog3-reference.py --check
python3 tools/native-validation/generate-slog3-ap0-reference.py --check
python3 tools/native-validation/generate-slog3-ap0-reference.py --gamut gamut3 --check
python3 tools/native-validation/generate-logc4-reference.py --check
python3 tools/native-validation/generate-vlog-reference.py --check
node tools/native-validation/compare-vlog-legacy.js
python3 tools/native-validation/generate-applelog-reference.py --check
node tools/native-validation/compare-applelog-legacy.js
node tools/native-validation/generate-slog3-legacy-baseline.js --check
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64 --stages tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outLegal.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outLegal.f64
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outData.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outData.f64
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17-inData-outLegal.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17-inData-outLegal.f64
python3 -m unittest tests/native_validation_batch_test.py tests/native_batch_manifest_test.py
plutil -lint Native/Apps/macOS/Info.plist Native/Apps/iOS/Info.plist Native/LUTCalc.xcodeproj/project.pbxproj
python3 tools/native-validation/verify-native-document-types.py
CHECKS
node --test tests/*.test.js
swift_jobs="${LUTCALC_SWIFT_JOBS:-$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN)}"
if [[ -n "$swift_test_pid" ]]; then
  if ! wait "$swift_test_pid"; then
    cat "$swift_test_log"
    exit 1
  fi
  swift_test_pid=""
  cat "$swift_test_log"
fi
swift_bin_path="$(swift build -c release --package-path Native/Packages/LUTKit \
  --jobs "$swift_jobs" --show-bin-path)"
run_product() {
  local product_name="$1"
  shift
  "$swift_bin_path/$product_name" "$@"
}
swift_module_path="$swift_bin_path/Modules"
if [[ ! -d "$swift_module_path" ]]; then
  swift_module_path="$swift_bin_path"
fi
swiftc -typecheck -parse-as-library -I "$swift_module_path" Native/Apps/macOS/LUTCalcMacApp.swift
run_contracts() {
  run_product LUTContractChecks \
    tests/fixtures/native-contracts/numeric-contracts.json \
    tests/fixtures/dlog2-reference.json \
    tests/fixtures/native-contracts/parser-contracts.json \
    tests/fixtures/native-contracts/first-chain-reference.json \
    tests/fixtures/native-contracts/srgb-reference.json \
    tests/fixtures/native-contracts/srgb-legacy-reference.json \
    tests/fixtures/native-contracts/srgb-plan-reference.json \
    "$@"
}
for legacy_suffix in "" "-inLegal-outLegal" "-inLegal-outData" "-inData-outLegal"; do
  if [[ -z "$legacy_suffix" ]]; then
    run_contracts tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64 \
      tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json
  else
    run_contracts "tests/fixtures/native-contracts/legacy-dlog2-exposure17${legacy_suffix}.f64"
  fi
done
python3 tools/native-validation/test-legacy-comparator-faults.py
dialect_dir="${TMPDIR:-/tmp}/lutcalc-cube-dialects-$(uuidgen)"
run_product LUTFormatChecks "$dialect_dir"
python3 tools/native-validation/verify-cube-dialects.py "$dialect_dir"
run_product LUTCatalogChecks
python3 tools/native-validation/run-check-batch.py \
  "$swift_bin_path" --workers "${LUTCALC_BATCH_WORKERS:-$cpu_count}"
python3 tools/native-validation/run-cube-batch.py "$swift_bin_path/LUTReferenceCLI" --workers "${LUTCALC_BATCH_WORKERS:-$cpu_count}"
run_product LUTProjectChecks
run_product LUTProjectSessionChecks
run_product LUTPreviewChecks
preview_dir="${TMPDIR:-/tmp}/lutcalc-preview-fixtures-$(uuidgen)"
python3 tools/native-validation/generate-preview-fixtures.py "$preview_dir"
sips -s format jpeg "$preview_dir/rgb8.png" --out "$preview_dir/rgb8.jpeg" > /dev/null
run_product LUTImageChecks "$preview_dir"
run_product LUTDocumentSampleChecks "$preview_dir"
run_product LUTJobChecks
run_product LUTSessionChecks
run_product LUTDocumentChecks
run_product LUTDocumentExportChecks
run_product LUTAnalysisChecks
echo "当前原生子集的静态与命令行契约通过；不等于双端 App 或发布验收。"
