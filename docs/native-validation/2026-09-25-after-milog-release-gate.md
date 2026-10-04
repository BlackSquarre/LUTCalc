# Mi-Log 接线后的完整回归与发布门槛

日期：2026-09-25。对应日志 `/tmp/lutcalc-milog-release-gate-20260925.log`。本记录只报告当前源码实际结果，不把新增曲线子集称为完整迁移。

运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`，最终退出码 **2**。代码、数值、三平台构建和 App 包审计均完成；入口因缺少真实 `docs/native-validation/full-scope-acceptance.json` 拒绝发布。

| 维度 | 实际结果 |
| --- | --- |
| Swift 契约 | `swift test --list-tests` 列出 137 项；Release 全包通过，0 失败 |
| Mi-Log 数值 | 33³/65³ 线性输出全节点最大尺度化误差 `3.933118393877112e-16` |
| 构建 | macOS、iOS Simulator、iOS generic 三个 Release 构建均 `BUILD SUCCEEDED` |
| App 包资源 | 3 个 App 包资源审计通过；不能据此证明二进制不存在等价采样表 |
| 真机 | 本次未运行；真机 SPI3D 既有记录独立保留，Files 和新增曲线真机数值继续暂缓 |
| 发布 | **未通过**。全量清单、完整功能兼容、许可审计、真机和交付证据仍未齐备 |

本次集中入口已连续验证 F-Log2、ACEScct、I-Log、Mi-Log 及既有曲线、格式、项目和预览契约。Mi-Log 的来源和公式边界见[阶段验收](2026-09-25-h11-milog-stage.md)。
