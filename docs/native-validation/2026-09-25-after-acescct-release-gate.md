# ACEScct 接线后的完整回归与发布门槛

日期：2026-09-25。对应日志 `/tmp/lutcalc-acescct-release-gate-20260925.log`。本记录只报告当前源码实际结果，不将新增子集称为完整迁移。

运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`，最终退出码 **2**。代码、数值和三平台构建均完成；入口因缺少真实 `docs/native-validation/full-scope-acceptance.json` 拒绝发布，未伪造清单。

| 维度 | 实际结果 |
| --- | --- |
| 代码边界 | 静态原生边界检查通过；运行时仍为 Swift，未加入 LUT、旧 `.labin` 或等价采样表资源 |
| 旧版回归 | Node 11 项、Python 审计 3 项通过 |
| Swift 契约 | `swift test --list-tests` 列出 129 项；Release 全包通过，0 失败 |
| 数值 | F-Log2、ACEScct 及既有曲线的批量标量/网格检查通过；ACEScct 33³/65³ 最大尺度化误差 `1.1102230246251565e-16` |
| 构建 | macOS、iOS Simulator、iOS generic 三个 Release 构建均 `BUILD SUCCEEDED` |
| App 包资源 | 3 个 App 包资源审计通过；不能据此证明二进制不存在等价采样表 |
| 真机 | 本次未运行。真机 SPI3D 已有独立记录；Files 独立读回、取消和新增曲线真机数值仍暂缓，最后集中执行 |
| 发布 | **未通过**。全量验收清单、全部功能兼容、完整来源/许可审计、真机和交付证据仍未齐备 |

本次同时验证了批量入口：一次 Release 构建后复用产品目录运行 22 个命令行检查，F-Log2 与 ACEScct 的数值 JSON 和既有检查结果均通过。阶段详情见[ACEScct 验收](2026-09-25-h11-acescct-stage.md)及[研究记录](2026-09-25-acescct-reference-research.md)。
