# H09/H11 原生曲线与色域选择器阶段验收

日期：2026-09-26

## 本阶段实现

- `TransformSettings` 新增 `withInput(transfer:space:)`，与已有输出复制方法保持相同的不可变设置语义。
- 输入和输出的曲线、色域 Picker 均直接读取 `AlgorithmCatalog.builtIn()` 的 Swift 注册表；界面不复制 JavaScript 注册表、采样数组或 LUT 资源。
- 切换曲线 ID 时清除不再匹配的参数化 Gamma 槽位；只切换色域或保留同一曲线 ID 时保留该槽位。
- 预设、范围、位深、白点适应、项目资源和撤销/重做路径保持原有项目包行为。

## 修改文件

- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`
- `Native/Packages/LUTKit/Tests/LUTCoreTests/ParameterizedGammaContractsTests.swift`

## 实际验证

源码版本：当前工作区 2026-09-26 版本；本记录未改动或复制研发 LUT、旧 `.labin` 或采样表到 App。

1. `swift test --package-path Native/Packages/LUTKit -c release`
   - 退出码：0。
   - 8 个 XCTest bundle，共 277 项测试；LUTFormats 的 2 项公开 NCP 实样按既有设计跳过；失败 0。
   - 日志：`/tmp/lutcalc-catalog-selector-swift-release-20260926-v3.log`。
   - 日志 SHA-256：`8e8cc78cacd6e44499e2753686d618aec718343a478acc71418897ba5211ca3c`。
2. `xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build`
   - 退出码：0，macOS Release 构建成功。
3. `xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
   - 退出码：0，iOS generic Release 构建成功。
4. `xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
   - 首次与另一构建并行执行时因 Xcode build database 锁定退出 65；未将该环境竞争算作代码失败。
   - 串行重跑退出码：0，iOS Simulator Release 构建成功。
   - 日志：`/tmp/lutcalc-ios-simulator-catalog-selector-20260926.log`。
   - 日志 SHA-256：`31c7af7d2ac28e6ad159e212c29acd91616b5eb778f26153a514a061664c1989`。
5. `bash tools/native-validation/verify-native-release.sh`
   - 退出码：2。
   - 公式检查、46 对 CUBE 生成/读回、Swift Release、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过。
   - 唯一门槛失败：缺少真实 `docs/native-validation/full-scope-acceptance.json`；没有伪造该清单。
   - 日志：`/tmp/lutcalc-catalog-selector-native-release-20260926-v3.log`。
   - 日志 SHA-256：`54221affeb79793d68871434b63e1f52e9b6b4a087adb55d9a3d08c56603b0d3`。

## 契约覆盖

新增 `testCatalogSelectionRetainsGammaOnlyForTheSelectedTransfer`、
`CatalogSelectionContractsTests.testInputAndOutputCatalogSelectionsPersistAndSupportUndoRedo` 与
`CatalogTransferSmokeTests.testEveryNonParameterizedCatalogTransferHasAFiniteSameSpaceRoundTrip`，验证：

- 只改输入色域时输入/输出 Gamma 均保持；
- 改输入曲线时只清除输入 Gamma；
- 改输出色域时输出 Gamma 保持；
- 改输出曲线时只清除输出 Gamma；
- 每个结果仍可通过 `validateParameterizedTransfers()` 并可进入 `TransformPlan`。
- 输入/输出目录选择写入项目包后可重开，撤销/重做保持有效；没有参数的参数化 Gamma 选择被项目校验拒绝。
- 每个当前注册的非参数化 transfer 都在其匹配色域执行有限值 smoke 计算；BBC WHP283 的已知黑位语义只作有限性检查，不把其非零黑位误报为失败。

## 未覆盖范围

本阶段只完成注册表选择器和参数槽位契约，不代表完整迁移。尝试读取已运行的 macOS App 时，桌面辅助功能返回 `AXError.apiDisabled`，因此没有把进程存在当作 Picker 点击或窗口呈现证据。完整旧曲线/色域、相机与调节链、任意 3D 反求、完整 ICC/显示色彩管理、HDR/EDR、File Provider 真机交互、iPad 多窗口旋转、目标软件往返、完整发布清单和 Goal 仍未完成。
