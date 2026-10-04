# H09/H11/H12 自定义 Gamma 原生编辑阶段验收

日期：2026-09-26。

## 范围

原生项目之前能保存和执行 `ParameterizedGammaSettings`，但项目界面无法输入或修改其五个参数。本阶段在 SwiftUI 项目文稿内增加输入与输出独立的编辑表单；没有既有参数时字段留空，由用户显式填写。`encodedCut` 留空表示使用既有 `linearSlope × linearCut` 规则。提交前所有文本必须解析为有限 Double，随后由既有 `ParameterizedGammaTransfer` 检查参数域。通过后一次性提交到原生项目，不改变其他设置、项目 ID、尺寸、输入域和资源。

编辑表单记录打开时的项目修订；若修订已变化，拒绝过期提交。取消、非法数字、非法参数和过期修订均不修改文稿。参数继续按原生项目 schema 存储为 Double；没有新增采样表、旧 `.labin`、厂商 LUT 或 Web 运行时。

修改文件及验收时 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTSharedUI/ParameterizedGammaEditor.swift`：`10f9a9a42b1ccaf5c61ae706ae1ce3e40900979b291b38ca8e349ad6658f3222`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift`：`44c2e9fe366edc8391a9c6f14387329298bbce43bccb8035882cccdc42dc98df`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：`119e130aac7297025ff138227a2ed7b912fa0095deaed5cdcaf35834d8f04154`。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/ParameterizedGammaEditorContractsTests.swift`：`e0477eff343b45d630d629fd7fdf4239b0583c103846b64a548489a20546530a`。
- `docs/native-swift-roadmap.md`。

既有冻结数值夹具未修改，版本见同日[参数化 Gamma 项目编辑保留验收](2026-09-26-h11-h12-gamma-editor-preservation.md)。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4，arm64 macOS 27.0。

1. `swift test --package-path Native/Packages/LUTKit -c release --filter ParameterizedGammaEditorContractsTests`：新增契约后先失败，编译明确报告缺少 `ParameterizedGammaDraft` 和 `applyParameterizedGamma`。实现后退出码 `0`，2/2 通过。合约覆盖输入/输出分别提交、项目包读回、撤销/重做、生成请求有效性、NaN/零指数拒绝、过期修订拒绝和失败不修改项目。
2. `bash tools/native-validation/verify-native-release.sh`：Swift Release 测试清单 272 项；7 个独立公式检查、46 对 33³/65³ CUBE 生成与独立读回、macOS/iOS Simulator/iOS generic Release 构建及三个 App 包资源审计通过。日志 `/tmp/lutcalc-gamma-ui-native-release-20260926.log`，SHA-256 `f6324000a0fc9a191182d718e4028175e8f81e06a9e96ac3030a8db2d54953e5`。可选旧 `.labin` 与公开 NCP 实样在无参数入口中按设计跳过。入口退出码 `2`，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

本阶段未改变 Gamma 数学实现；现有独立公式和 CUBE 读回仍通过，不宣称新的准确度提升。

## 未覆盖

macOS 桌面辅助功能接口此前返回 `AXError.apiDisabled`，本阶段未获得表单实际点击证据。iOS/iPadOS 真机输入、系统文稿保存、Files/File Provider 与多窗口协调未验证。完整旧 Gamma 选择器和调节链、相机范围、CDL、HDR/EDR、完整 LUTAnalyst、H09/H11/H12 全量工作与发布验收仍未完成；Goal 保持进行中。
