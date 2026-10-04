#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

# 发布入口保留真实全量清单门槛；缺少清单时必须失败，不能由脚本自动生成或绕过。
bash tools/native-validation/verify-native-release.sh
