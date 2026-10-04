# H10 导入 LUT 结构分析与一维反求阶段验收

日期：2026-09-26。

## 范围与实现

本阶段在既有 `MonotonicCurve1D`、`.lacube/.labin` 解析和用户导入会话上接线。`ImportedLUTAnalyzer` 分别检查 R/G/B 原始样本，报告严格单调、平段与反转；只允许三个 transfer 通道均严格单调时逐通道反求。域外目标返回 `outsideTransferRange`，平段或反转返回 `nonUniqueTransfer`。反求使用既有 Double 求根器，未修改样本、网格尺寸、位宽、插值或容差。

分析文件的 1D transfer 和 3D colour 分节保持独立。组合 CUBE 的 shaper 另列结构报告；它的单调性不证明后续 3D 部分可逆。任意 3D LUT 反求返回 `arbitrary3DInverseUnsupported`，没有从节点拟合出“已知仿射”模型。SwiftUI 显示结构报告、1D 反求字段和三维边界，并为 `.lacube/.labin` 的独立 colour 分节提供灰轴检查。会话切换、清除、关闭和新导入均清除旧分析与反求结果。

修改文件：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/UserLUTImportSession.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTImportContractsTests.swift`
- `docs/native-swift-roadmap.md`

上述五个 Swift 文件在验收时的 SHA-256 依次为：`476a887aa5033813eea5c1a3c1d9b8c3d42c6c81875ab667cf843d5e6230ae32`、`52c63317ddf7c3b70bb95cfd95bdf555cc63d15dd3c7bff2fb023fb0e2b79b46`、`2669b2733eb7bd9b776102554e2aec012afefcae682cd5a6669af9e9056b98cb`、`a207a8daae24d9c6fcef38dc704e51003d92fe3014e8691cfa0a733afd12be67`、`c4e3964278265c39ca56f60fea8b39f31c476e659989ae03493e91bb464e9c2b`。

研发夹具 `V709.labin` 的 SHA-256 为 `f835bcb68766a119f11af2ba74c186088c6541e79db4bfb992abe9439f887c48`；冻结数值、解析和哈希夹具 `tests/fixtures/native-contracts/{numeric-contracts.json,parser-contracts.json,sha256.json}` 的 SHA-256 分别为 `217a1138bc6dee0d041608bbadd00264dacf377184b0f43ef2ea4ce68e7a9d8b`、`ddf6a9f19e26a482de88bb1ead1681b5ee70dff803da5f3e0d1e4856cbbf1086`、`5345aa63d408fcfe28ac4bc242c15faa851c3b71c01bfa3ed6d39bed789d5e5a`。旧 `.labin` 与冻结夹具只用于研发验证，不进入 App。

## 实际验证

工具链：Xcode 27.0（27A266a），Apple Swift 6.4；主机 arm64 macOS 27.0。

1. 新增的结构和会话契约先运行失败，分别报缺少 `ImportedLUTAnalyzer`、`inspectStructure`、`inverseTransfer`；实现后定向测试通过。结构契约 4 项，导入会话测试类 6 项，其中新增 2 项。
2. `swift test --package-path Native/Packages/LUTKit -c release`：退出码 `0`，测试清单 265 项。完整日志 `/tmp/lutcalc-h10-import-analysis-swift-release-20260926.log`，SHA-256 `a0b9a3a75a8c404a35433745360c9ad70bd58dfa7a1d1768e136318cca4c70cb`。可选公开 NCP 实样与旧 `.labin` 环境变量测试在该无参数运行中跳过。
3. `LUTCALC_LABIN_SAMPLE=/Users/lingru/claude/LUTCalc/V709.labin swift test --package-path Native/Packages/LUTKit -c release --filter LUTAnalysisFileContractsTests/testLegacyLABinFixtureIsParsedOrReportsLossyBoundary`：退出码 `0`；该研发夹具测试通过。日志 SHA-256 `7ebbc658e0297961d680873f526e21c5466de6c2655fa78bb47fd91073ef8b98`。
4. `bash tools/native-validation/verify-native-release.sh`：7 个批量公式检查、46 对 33³/65³ CUBE 生成与独立读回、原生子集、macOS/iOS Simulator/iOS generic 三平台 Release 构建和三个 App 包资源审计通过。最终日志 `/tmp/lutcalc-h10-import-analysis-native-release-final-20260926.log`，SHA-256 `cb7c10bd393cf55c971aa7054621560a2dfd357b6e952404f8496ef1df988e31`。入口退出码 `2`，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`，未伪造清单。

新一维往返契约的逐通道绝对误差均低于原有 `2e-12` 门槛；域外、平段和反转有明确失败结果。此处不宣称三维重建误差或完整 TF/颜色分离准确度。

## 未覆盖与结论

代码、Swift 契约及三平台 Release 构建已验证；本阶段没有执行 macOS 实际点击、iOS/iPadOS 真机 Files/File Provider 文件选择、项目保存/取消、多窗口交互或目标软件往返。完整 LUTAnalyst TF/颜色分离、任意 3D 反求专项规格、旧 cubic/tricubic 插值、完整旧调节链及全量发布验收仍未完成。H10、FULL-05 与 Goal 保持未完成。
