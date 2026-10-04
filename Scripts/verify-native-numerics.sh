#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

# 统一入口复用已冻结的原生子集契约；脚本不改变网格、位宽、插值或误差阈值。
bash tools/native-validation/verify-native-subset.sh
