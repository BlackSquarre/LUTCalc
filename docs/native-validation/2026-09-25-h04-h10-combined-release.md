# H04 NCP 读取与 H10 用户 LUT 灰轴合并回归

日期：2026-09-25。对应[H04 NCP `0100` 只读子集](2026-09-25-h04-ncp-0100-read.md)和[H10 用户 LUT 灰轴接线](2026-09-25-h10-imported-gray-axis.md)。

执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-gray-axis-import-release-20260925.log`，SHA-256 `b9966b62f2ab0c3c9beb5da7ea55869c22f782ba98772e86279fd8c8a864740c`。本次 Swift 测试已包含同批新增的 3 项 NCP 契约与 2 项组合 CUBE 灰轴契约。

| 门槛 | 实际结果 |
| --- | --- |
| Swift Release XCTest | 190 项执行，0 失败 |
| 独立数值批次 | 6 个公式检查、36 对 33³/65³ CUBE 生成与独立逐节点读回通过；Double 与既有门槛未变 |
| 平台构建 | macOS、iOS Simulator、iOS generic 三个 Release 构建通过 |
| App 包资源 | 3 个实际 App 包审计通过；未列入 NCP 实样、厂商 LUT、旧 `.labin` 或脚本 |
| 真机 | 本轮未运行；连接不稳的剩余 Files/取消项目留待最后集中处理 |
| 发布 | 入口退出码 2，缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建占位清单 |

NCP 读取仍未接入界面，亦无 Nikon 软件或相机兼容证据；灰轴只报告用户 LUT 的输入域对角线。上述合并回归不计 H04/H10、FULL-05/FULL-06 或完整迁移完成。
