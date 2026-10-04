# H09/H11 项目范围与白点适应编辑验收

日期：2026-09-26。

## 范围

原生 SwiftUI 项目文稿界面新增三个已存在于 `TransformSettings` 的设置入口：输出 Data/Legal 范围、范围位深 8/10/12、色彩适应 CIE CAT02/Bradford。`TransformSettings` 增加保留全部字段的复制方法，避免编辑这些设置时丢失输入/输出参数化 Gamma。设置应用仍经项目验证和事务历史；位深只允许 8、10、12，其他值不进入界面提交。

## 修改与证据

修改文件：

- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift`，SHA-256 `55b2aa1c1739b1025a8b47ad02b8da9e13d99b7ce4b722f565e9cb898dcd83a8`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`，SHA-256 `215b8d104726a6acc305c71fcecbff26b1c1b6309e14cf83dd990abbc58c399d`。
- `Native/Packages/LUTKit/Tests/LUTCoreTests/ParameterizedGammaContractsTests.swift`，SHA-256 `6a5a662e5593daad31a69390605a6de3a3f96e3afd39bd2580555fa65833069d`。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTProjectAssetContractsTests.swift`，SHA-256 `dd1d01269d287a876d4f025ebb64e9a4fee39a5f1c5b8220c275aa84f9ef118b`。
- `docs/native-swift-roadmap.md`。

## 实际验证

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4，arm64 macOS 27.0。

1. 新契约先运行失败，编译报告缺少 `withOutputRange`；补齐复制方法与界面绑定后，定向 `swift test --package-path Native/Packages/LUTKit -c release --filter ParameterizedGammaContractsTests/testRangeDepthAndAdaptationEditsPreserveParameterizedGammaSlots` 通过。
2. `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests/testRangeAndAdaptationChangesPersistWithGammaAndKeepResources` 退出码 `0`；验证 12 位 Legal、Bradford、两侧 Gamma、普通资源字节、项目包重开、生成请求和撤销。
3. `bash tools/native-validation/verify-native-release.sh`：Swift 测试清单 274 项，7 个独立公式检查、46 对 33³/65³ CUBE 读回、macOS/iOS Simulator/iOS generic Release 构建和三个 App 资源审计通过。日志 `/tmp/lutcalc-range-editor-native-release-20260926.log`，SHA-256 `8f5ef9150dc5b5ceb609ef65901374cf775ed22666754bf0f92f4da6a6778cc5`。发布入口退出码 `2`，原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

本阶段没有修改转换公式、插值、网格尺寸、位宽精度路径或测试阈值；新增位深只是暴露已有范围参数并由既有 `CodeRange` 校验。

## 未覆盖

未完成 macOS 实际点击与系统文稿交互、iOS/iPadOS 真机、Files/File Provider、多窗口、完整显示色彩管理、HDR/EDR、完整旧调节链及发布验收。Goal 继续进行中。
