#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"

if ! xcodebuild -version; then
  echo "发布门槛未通过：缺少可用的完整 Xcode。" >&2
  exit 2
fi
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk iphonesimulator --show-sdk-path
cpu_count="${LUTCALC_CPU_COUNT:-$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 1)}"
derived_data_path="${LUTCALC_DERIVED_DATA_PATH:-$project_root/Native/DerivedData}"
mac_data="$derived_data_path/macOS"
sim_data="$derived_data_path/iOS-Simulator"
device_data="$derived_data_path/iOS-Device"
mac_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-release-mac.XXXXXX")"
sim_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-release-sim.XXXXXX")"
device_log="$(mktemp "${TMPDIR:-/tmp}/lutcalc-release-device.XXXXXX")"
cleanup_release() {
  for pid in "${mac_pid:-}" "${sim_pid:-}" "${device_pid:-}" "${subset_pid:-}" "${audit_test_pid:-}"; do
    [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true
  done
  rm -f "$mac_log" "$sim_log" "$device_log"
}
trap cleanup_release EXIT
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$mac_data" \
  -jobs "$cpu_count" -parallelizeTargets CODE_SIGNING_ALLOWED=NO build >"$mac_log" 2>&1 & mac_pid=$!
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$sim_data" \
  -jobs "$cpu_count" -parallelizeTargets CODE_SIGNING_ALLOWED=NO build >"$sim_log" 2>&1 & sim_pid=$!
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$device_data" \
  -jobs "$cpu_count" -parallelizeTargets CODE_SIGNING_ALLOWED=NO build >"$device_log" 2>&1 & device_pid=$!

# Start independent package/UI validation while the three platform builds compile.
LUTCALC_RUN_SWIFT_TEST=1 bash tools/native-validation/verify-native-subset.sh & subset_pid=$!
python3 -m unittest tests/native_bundle_audit_test.py & audit_test_pid=$!
validation_status=0
wait "$subset_pid" || validation_status=1
subset_pid=""
wait "$audit_test_pid" || validation_status=1
audit_test_pid=""
if (( validation_status != 0 )); then
  exit "$validation_status"
fi

build_status=0
wait "$mac_pid" || build_status=1
mac_pid=""
wait "$sim_pid" || build_status=1
sim_pid=""
wait "$device_pid" || build_status=1
device_pid=""
cat "$mac_log" "$sim_log" "$device_log"
if (( build_status != 0 )); then exit "$build_status"; fi
mac_app="$mac_data/Build/Products/Release/LUTCalcMac.app"
ios_sim_app="$sim_data/Build/Products/Release-iphonesimulator/LUTCalcIOS.app"
ios_app="$device_data/Build/Products/Release-iphoneos/LUTCalcIOS.app"
python3 tools/native-validation/audit-native-bundles.py "$mac_app" "$ios_sim_app" "$ios_app"
python3 tools/native-validation/check-release-evidence.py
echo "自动构建与证据结构检查完成；仍需人工核对证据真实性、功能覆盖和发布内容。"
