# 旧版 F-Log2 兼容候选后的批量回归与发布门槛记录

日期：2026-09-25

完整入口：`bash tools/native-validation/verify-native-release.sh`

完整日志：`/tmp/lutcalc-flog2-legacy-release-20260925.log`；SHA-256：`0b4543c988ab685393a325d8d1189e0ba094962dee1dbe7daa51b1963cea70c2`。

- `swift test --package-path Native/Packages/LUTKit list` 当前为 **151 项**。
- 旧 Node 契约、Python 参照、静态边界和实际 App 包资源审计通过。
- macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`。
- 注册表为 19 条曲线、12 个色域、19 个预设；旧版 F-Log2 33³/65³ 批量逐节点检查通过。

发布入口退出码为 **2**，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。没有伪造清单，也没有把本阶段结果称为完整迁移或发布就绪。

真机新增曲线、Files 独立读回/取消、第三方导入、完整 H01–H14 与真实全量发布验收仍未完成。
