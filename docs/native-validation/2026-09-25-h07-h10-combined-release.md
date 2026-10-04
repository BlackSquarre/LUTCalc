# H07 项目资产与 H10 灰轴合并回归

日期：2026-09-25。对应[H07 项目资产阶段验收](2026-09-25-h07-user-lut-project-asset.md)和[H10 灰轴阶段验收](2026-09-25-h10-gray-axis-extraction.md)。

执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-h07-h10-combined-release-20260925.log`，SHA-256 `1e1ca570925a6a72f905b4bd6771b1146315fe051eb8f1ca6bab1ac4db2c46a3`。

| 门槛 | 实际结果 |
| --- | --- |
| 静态原生边界 | 79 个 Swift 源文件检查通过；未发现所列禁止运行时或内置 LUT 资源 |
| Swift Release XCTest | 185 项执行，0 失败 |
| 公式与数值批处理 | 6 个独立公式检查、18 条预设的 33³/65³ 共 36 对 CUBE 生成和独立逐节点读回通过；原冻结 Double 门槛未改 |
| 平台构建 | macOS、iOS Simulator、iOS generic 三个 Release 构建通过 |
| 实际 App 包资源 | 3 个 App 包审计通过，未发现列明的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接 |
| 真机 | 本轮未执行；已取得的 SPI3D 真机单项证据与剩余 Files/取消事项分别保留 |
| 发布 | 入口退出码 2：缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单 |

上述数值检查涵盖既有预设与新灰轴定向契约，不能推论全部旧调节、格式/方言、目标软件或设备路径已完成。H07/H10、完整迁移及发布门槛保持未完成。
