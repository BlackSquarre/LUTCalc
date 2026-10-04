# H07/H10 分析文件独立 3D 分节取样验收

日期：2026-09-26。

## 范围

用户主动导入的 `.lacube/.labin` 分析文件可能同时包含 1D transfer 和独立 3D colour LUT。现以显式 `UserLUTSampleSection` 区分直接取样目标；默认调用仍取原主 LUT，选择 `.colour` 才读取独立 3D 分节。缺少该分节时返回 `noColourSection`。此操作不合成两段，也不加入内置算法或项目生成计划。

SwiftUI 在确有 colour 分节时提供 `1D transfer`/`3D colour` 选择，并标明结果所属分节。切换或清除导入会话会清除旧结果；灰轴检查读取该文件的 colour 分节。直接取样使用既有 Swift Double 解析与插值实现，未更改插值方式、网格、位宽或精度门槛。

修改文件：

- `Native/Packages/LUTKit/Sources/LUTSharedUI/UserLUTImportSession.swift`，SHA-256 `b70ea92ba4d01ee904bd0b50e183c7febe4a517460ceb10b90dba2cfb8845570`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`，SHA-256 `8d1fce4ec5cc2b7e7f29df953de78347c7dbbabac80592ae667e1cebbe218f18`。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTImportContractsTests.swift`，SHA-256 `fa5fe13e869029602c28b8508a5420d0720398e0c07b7ded65fa6643fff5f590`。
- `docs/native-swift-roadmap.md`。

冻结数值夹具未修改；其版本哈希见同日[H10 导入分析验收](2026-09-26-h10-imported-lut-analysis.md)。

## 实际验证

工具链：Xcode 27.0（27A266a），Apple Swift 6.4；主机 arm64 macOS 27.0。

1. `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTImportContractsTests/testAnalysisFileColourSectionSamplingIsExplicitAndIndependent`：先失败，报缺少 `section` 参数和 `sampleSection`。实现后 `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTImportContractsTests` 退出码 `0`，7/7 通过。合成 2³ colour 样本在 `(1,1,1)` 输出 `(0.5,0.25,0.75)`，主 1D 同点输出 `(1,1,1)`，逐通道误差为 `0`；缺失分节拒绝路径通过。
2. `bash tools/native-validation/verify-native-release.sh`：7 个公式检查、46 对 33³/65³ CUBE 生成与独立读回、完整 Swift Release 测试、macOS/iOS Simulator/iOS generic 三平台 Release 构建及三个 App 包资源审计通过。最终测试清单 266 项；可选 NCP 实样及旧 `.labin` 环境变量测试在无参数入口中按设计跳过，后者已在同日 H10 记录中以 `V709.labin` 单独通过。日志 `/tmp/lutcalc-h07-colour-section-native-release-20260926.log`，SHA-256 `0c55d174aa764d3267df32f353d86d2eeb88881823773e18a490b7f191957dbd`。入口退出码 `2`，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`，未伪造清单。

## 未覆盖

未进行 macOS 实际点击或 iOS/iPadOS 真机 Files/File Provider 选择；没有自动组合 1D/3D、任意 3D 反求、旧 cubic/tricubic 插值或目标软件读回。H07、H10、FULL-05 与 Goal 均保持未完成。
