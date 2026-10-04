# H04 CUBE 首通道非有限值诊断阶段验收

日期：2026-09-25。状态：定向契约通过，H04/FLOW-01 仍未完成。

## 依据与缺口

`docs/native-swift-runtime-contracts.md` 第 3.1 节要求每行恰好三个有限通道，拒绝 NaN/Infinity，并保留行号；`docs/native-swift-precision.md` 第 3 节也要求非有限输入返回可诊断失败。此前 `CubeParser` 先用样本行首字符区分数值与未知指令，导致首通道为 `NaN` 或 `Infinity` 时返回 `unsupported`，而相同值位于后两个通道时返回 `nonFiniteValue`。本次只修正错误类别，不更改数值解析、输入域、写出格式或组合 CUBE 语义。

## 契约、实现与验证

- 先在 `CubeContractsTests` 增加 `NaN`、`Infinity`、`-inf` 位于首通道的契约，要求 `nonFiniteValue` 和第 2 行。首次执行 `swift test --package-path Native/Packages/LUTKit -c release --filter CubeContractsTests/testNonFiniteFirstChannelIsReportedAsSampleError`：1 项测试失败，其中 2 个断言得到 `unsupported`，确认可复现。
- 随后在 `CubeParser` 样本行首字符判断前识别非有限 token，并让首通道预检查与三个通道的数值解析共用同一分类函数。再次执行 `swift test --package-path Native/Packages/LUTKit -c release --filter CubeContractsTests`：7 项通过，0 失败。未知语义指令仍由原分支报 `unsupported`。
- 另一次尝试扩大到 `--filter LUTFormatsTests` 时，包构建被并行开发中的 `LUTDocumentSampleChecks/main.swift` 调用尚未出现的 `ProjectSampleSession.resetForDocumentSwitch()` 中断；该失败不属于 CUBE 解析，也不能计为完整格式回归。整合后须重新执行受影响测试及三平台构建。

整合后的当前源码已执行 `bash tools/native-validation/verify-native-release.sh`（日志 `/tmp/lutcalc-h04-h13-integrated-release-20260925.log`）：Node 11 项、Python 审计 3 项、Swift Release XCTest 121 项、macOS/iOS Simulator/iOS generic 三个 Release 构建和三个 App 包资源审计通过。入口最终退出码 2，原因仍是缺少真实全量发布验收清单；上述并行构建中断已不再存在。

工具链：Apple Swift 6.4，arm64-apple-macosx27.0.0。参与文件 SHA-256：`Cube.swift` 为 `ceaa1330fb3e4f20e2b25744fb8c6a428b52c5ebb0efa3160d16ed8fec2683be`，`CubeContractsTests.swift` 为 `8f27ee14e110c60f62db0eb7568e6ec95ec63633023c16a4d47135676eec083e`。本次没有改动冻结夹具、精度门槛或旧 `.labin` 资源。

剩余：CUBE 目标软件导入、组合 `DOMAIN_MIN/MAX` 语义、Files 真机独立读回、各方言的完整兼容和发布验证仍按路线图推进。本阶段不能作为 H04、FLOW-01 或完整迁移验收。
