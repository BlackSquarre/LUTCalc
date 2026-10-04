# H11/H12 原生项目编辑保留参数化 Gamma 验收

日期：2026-09-26。

## 问题与范围

原生项目已能保存 `inputGamma`/`outputGamma`，但 `EditorSession` 与 `ProjectDocumentView` 的曝光、输入范围和输出目标编辑会直接重建 `TransformSettings`，遗漏两个参数槽位。结果是原项目中合法的参数化 Gamma 在普通编辑后可能丢失，或者切换固定输出时发生不匹配。本阶段只修复项目设置复制与槽位匹配，不改颜色公式、Double 生成、网格、位宽或测试容差。

`TransformSettings.withInputRange`、`withExposureStops` 保留其余全部字段；`withOutput` 保留输入 Gamma，只有输出曲线身份未变时才保留输出 Gamma。两个原生编辑入口共用这些方法，保存/重开仍走现有原生项目事务。

修改文件及验收时 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift`：`a726bd512b202406efe32dc1dee550ffea7a70558ef0927d5d19e6584cf80d86`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift`：`7d13794d29619c31844b8ee69d19ff9e36d3a8a9c68933fee578fbc2ca922ba8`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：`e1df30b7b06ac0474a7d04bbab3c19b9eb42ff0d2ea25194ae7e2c35ea5fbb32`。
- `Native/Packages/LUTKit/Tests/LUTCoreTests/ParameterizedGammaContractsTests.swift`：`f8574eb88856e5707e9b162ef309b7c05759e5ab3391c85df9e79e25fc3b0632`。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/SessionContractsTests.swift`：`2f51608b49be2ecda0a0ad8856e380e627fb6627f08b0310dc4d9897fad5199b`。
- `docs/native-swift-roadmap.md`。

冻结夹具未修改；`tests/fixtures/native-contracts/sha256.json` 的 SHA-256 仍为 `5345aa63d408fcfe28ac4bc242c15faa851c3b71c01bfa3ed6d39bed789d5e5a`。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4，arm64 macOS 27.0。

1. 新增契约后先运行 `swift test --package-path Native/Packages/LUTKit -c release --filter ParameterizedGammaContractsTests/testUnrelatedSettingEditsPreserveBothGammaSlotsAndOutputSwitchClearsOnlyOutput`：编译失败，明确缺少 `withInputRange` 等复制方法。
2. 实现后运行 `swift test --package-path Native/Packages/LUTKit -c release --filter 'ParameterizedGammaContractsTests|SessionContractsTests'`：退出码 `0`；两个测试类分别 7/7、5/5 通过。新增契约验证双参数槽位、Bradford 和范围/曝光保留，切换固定输出只清除输出参数，并用原生 `.lutcalc` 文件保存、重开验证。
3. `bash tools/native-validation/verify-native-release.sh`：Swift Release 测试清单 268 项；7 个独立公式检查、46 对 33³/65³ CUBE 生成与独立读回、macOS/iOS Simulator/iOS generic Release 构建和三个 App 包资源审计通过。日志 `/tmp/lutcalc-gamma-edit-native-release-20260926.log`，SHA-256 `8aa464e0e681d4011e004b3499e1f527a13e76d5bdf968e518258c87841f3f54`。可选公开 NCP 与旧 `.labin` 实样在无参数入口中按设计跳过。入口最终退出码 `2`，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

此次是设置复制契约，不涉及数值算法变更；原有 7 个独立公式检查及 46 对 CUBE 节点读回保持通过。没有声称新的准确度提升。

## 未覆盖

尚未做 macOS 实际编辑点击、iOS/iPadOS 真机项目打开/保存与多窗口文件协调。参数化 Gamma 的完整可视化编辑器、完整旧调节链、H11/H12 全量功能和发布验收仍未完成；Goal 保持进行中。
