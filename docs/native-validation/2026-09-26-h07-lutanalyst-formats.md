# H07 LUTAnalyst `.lacube` / `.labin` 格式接入验收

日期：2026-09-26。

## 范围

本阶段只迁移 LUTAnalyst 文件的严格读写和用户资产接线：`.lacube` 的 1D/可选 3D CUBE 分段、`LA_*` 元数据；`.labin` 的 little-endian Int32 样本、独立输入矩阵缩放和 ASCII 元数据。该格式不能作为内置算法资源，旧文件只用于研发核验。

## 修改

- `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`
  - `LUTAnalysisFile`、分段元数据和失败分类。
  - `LACubeParser` / `LACubeWriter`。
  - `LABinParser` / `LABinWriter`。
  - 文件长度、维度乘法、UTF-8、元数据、有限值、little-endian 和旧 `±1.99` 有损哨兵检查。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/UserLUTImportSession.swift`
  - 新增 `.lacube` / `.labin`，保留分析载荷并继续提供 1D LUT 直接取样。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`
  - 系统文件选择器允许两个用户分析格式。
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`
  - 4 项解析/写出/损坏边界契约。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTImportContractsTests.swift`
  - 导入会话分析载荷接线契约。

## 实际验证

工具链：Xcode 27.0（27A266a）、Swift 6.4、macOS 27 SDK，Apple Silicon。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisFileContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter UserLUTImportContractsTests.testLUTAnalystFormatsExposeAnalysisPayload
LUTCALC_LABIN_SAMPLE=/Users/lingru/claude/LUTCalc/V709.labin \
  swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisFileContractsTests.testLegacyLABinFixtureIsParsedOrReportsLossyBoundary
LUTCALC_LABIN_SAMPLE=/Users/lingru/claude/LUTCalc/Cine709.labin \
  swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisFileContractsTests.testLegacyLABinFixtureIsParsedOrReportsLossyBoundary
```

结果：格式契约 4/4 通过；用户会话接线 1/1 通过；`V709.labin` 研发夹具读取通过；`Cine709.labin` 的旧 `2,136,746,230` 哨兵被识别为有损边界并按失败契约处理。没有把任何 `.labin`、厂商 LUT 或采样数组加入 Swift Package 或 App 资源。

完整 Swift Release 回归：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`；新增用户分析接线测试通过，既有各目标测试继续通过。日志 SHA-256：`39963bdf9b6be827cfaa911d46f407f51d3796307024e9839d1699e83ca97cfd`。

原生发布入口：

```sh
bash tools/native-validation/verify-native-release.sh
```

静态源码边界、7 个公式检查、46 对 33³/65³ CUBE 生成/独立读回、原生子集、macOS Release、iOS Simulator Release、iOS generic Release 和 3 个 App 资源审计均通过。该入口最终退出码为 `2`，原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`，不是本阶段代码或构建失败。日志 SHA-256：`c1396db7504f98d1ea1f9b80c75e399185f0ba44646312a4f2578344c99db831`。

本阶段源码哈希：`LUTAnalysisFile.swift` `603ce33efbad7673342dae202dcadd70639d5c7f3bd1289f01f4e8716e0c65b9`；`UserLUTImportSession.swift` `c3837eb7051ab64e39aa7ef5db0cd0d59fac18b2dd81d5eb52fded6752a9c782`；格式契约 `f96d4f75683e9a66b625af104fbdaee1cf9289a8387301982ddb5f3928771369`；用户接线契约 `8b1344717010e02c20d268ed3e0d19463689daef18d82a68c1b3ee9675f2f39f`。

## 未覆盖

本阶段不包含完整 LUTAnalyst 的 TF/颜色分离、任意 3D 反求、旧 cubic/tricubic 插值、完整元数据语义恢复、目标软件往返、真机 Files/File Provider 交互、HDR/EDR 或全量 H01–H14 发布验收。发布入口仍需要真实 `docs/native-validation/full-scope-acceptance.json`，Goal 保持 active。
