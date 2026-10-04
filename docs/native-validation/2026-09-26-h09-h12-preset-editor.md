# H09/H12 原生项目目录预设界面阶段验收

日期：2026-09-26。

## 范围

项目文稿的 SwiftUI 界面现可选择 `AlgorithmCatalog.builtIn()` 中已有的转换预设。选择动作只替换 `TransformSettings`，保留原生项目 ID、3D 网格尺寸、输入域及所有资源的 SHA-256、角色和原始字节；项目事务保留撤销、重做及保存重开。界面在当前设置与目录预设完全一致时显示该预设，否则显示“项目当前设置”。

这只打开已登记且通过现有数值契约的预设入口。目录中新增候选能力依旧按来源与覆盖调查分别跟踪；预设数量不代表旧功能迁移完成。界面标签当前使用稳定预设 ID，完整视觉和交互设计仍待验收。

修改文件及验收时 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift`：`424453519c65d0593f2b1843b42af0775b14cfb13bba0f3f9abbd1e3819523c3`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：`7f4b28c9588ff52db516ac2732437116cbc20c176782a5b80ce3108a88db56a3`。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTProjectAssetContractsTests.swift`：`efaf81287090684987642a587f945303dd7ea5c691746c4dd4a89c4e1d843e92`。
- `docs/native-swift-roadmap.md`。

沿用同日 H11/H12 验收记录中的冻结数值夹具；未修改夹具或公式。

## 实际验证

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4，arm64 macOS 27.0。

1. 新增项目契约后先执行 `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests/testApplyingCatalogPresetPreservesProjectEnvelopeAndSupportsUndo`：编译失败，明确缺少 `LUTProjectDocument.applyPreset`。实现后该契约通过，核对普通资源字节、SHA-256、角色、项目 ID、33³ 尺寸、输入域、撤销/重做和包级重开。
2. `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests/testEveryPresentedCatalogPresetCanBecomeAProjectAndGenerationRequest`：退出码 `0`，遍历当前内置预设，各项都能构成有效原生项目和生成请求。
3. `bash tools/native-validation/verify-native-release.sh`：Swift Release 测试清单 270 项；7 个独立公式检查、46 对 33³/65³ CUBE 生成与独立读回、macOS/iOS Simulator/iOS generic Release 构建、三个 App 包资源审计通过。日志 `/tmp/lutcalc-preset-ui-native-release-20260926.log`，SHA-256 `8e45d0db88b22ec3341258855cdc342119710189e3eea0548ba51475b731186a`。入口退出码 `2`，直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。
4. 本机 `pgrep -fl LUTCalcMac` 可见从 Xcode Release 产物路径运行的进程；尝试使用桌面 UI 自动化读取原生窗口时返回 `AXError.apiDisabled`。因此本项只作为进程存在证据，不能证明界面呈现、预设点击或系统文稿交互。

本阶段不修改 Double 颜色计算；数值证据来自未变更的公式和生成读回回归，没有声称新精度提升。

## 未覆盖

没有实际 macOS 点击或 iOS/iPadOS 真机预设交互、Files/File Provider 保存及多窗口协调。任意参数 Gamma 的可视化编辑、完整旧控件、相机范围、CDL、Highlight Gamut、Knee、Limiter、HDR/EDR、完整 LUTAnalyst 与发布验收仍未完成。H09/H12 与 Goal 保持进行中。
