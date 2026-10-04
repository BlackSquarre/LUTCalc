# 2026-10-03 严格 1D cubic 反求项目持久化与导出传播验收

## 范围

本阶段只处理已验证的严格单值 `tricubicLegacyV1` 1D transfer 反求在非 UI 路径中的接入：`.lutcalc` 项目清单、用户 LUT 资产哈希、项目重开、曝光批次和导出服务。任意 3D LUT 反求、病态曲线报告、完整 LUTAnalyst、UI 与系统文件交互仍不在本阶段范围。

## 契约先行

先新增并运行红灯契约，确认尚不存在 `UserLUTInputInverseSettings`、清单字段和导出传播：

```text
swift test --package-path Native/Packages/LUTKit --filter 'UserLUTInverse(Project|Export)ContractsTests'
```

红灯结果为编译失败：缺少 `UserLUTInputInverseSettings`，且 `ProjectManifest` 没有 `userLUTInputInverse` 参数。未修改旧用户数据或删除工作区文件。

## 实现

- `ProjectManifest.currentSchema` 从 22 升为 23。
- 新增 `UserLUTInputInverseSettings`，清单只保存用户 LUT 资产相对路径与 `tricubicLegacyV1` 算法身份。
- 清单严格要求反求路径是唯一的 `.userLUT`／`.legacyUserLUT` 资产；路径不匹配、多个用户 LUT、非 cubic 插值和旧 schema 偷带该字段均拒绝。
- 项目生成请求从已校验哈希资产重建 `ImportedLUTInversePlan`，不会从任意 3D LUT 推断可逆性。
- 曝光批次复制 `inputTransferInverse`，并把插值身份纳入批次指纹。
- 1D 导出在请求带输入反求时明确返回 `SPI1DFailure(.lossyRepresentation)`，防止把只适用于 3D 网格的输入反求静默丢弃。
- 3DL shaper 与输入反求同时存在时沿用 `JobFailure.conflictingInputTransforms`；无 shaper 的 3D 导出保留反求。

## 测试与结果

定向 Debug／Release：

```text
swift test --package-path Native/Packages/LUTKit --filter 'UserLUTInverse.*ContractsTests'
```

共 5 项新契约通过，0 失败。覆盖项目清单往返、资产绑定、项目包重开、批次每项传播与指纹差异、1D 导出拒绝。

Debug 全量：

```text
swift test --package-path Native/Packages/LUTKit
```

实际启动 584 项，2 项既有 `.labin`／NCP 外部夹具跳过，0 失败；日志 `/tmp/lutcalc-cubic-project-inverse-debug-20261003.log`，SHA-256：`1f49bca7f2d45dd0da2a04439aa13a167b16eaede0263342c27319034afb7dbf`。

Release 全量：

```text
swift test -c release --package-path Native/Packages/LUTKit
```

实际启动 584 项，2 项既有 `.labin`／NCP 外部夹具跳过，0 失败；日志 `/tmp/lutcalc-cubic-project-inverse-release-20261003.log`，SHA-256：`6b47f714ab036eba99b38c1ccdd94bc5978972f0ccf74f828c2ab1b343625b89`。

## 平台构建

工具链为 Xcode 27.0、Swift 6、macOS 27 SDK、iOS 27 SDK。默认 Xcode DerivedData 路径在本机出现目录写入／CoreSimulator 内存错误；使用独立 `/tmp` DerivedData 后成功：

```text
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -derivedDataPath /tmp/lutcalc-inverse-mac-dd -destination 'generic/platform=macOS' build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -derivedDataPath /tmp/lutcalc-inverse-ios-dd -destination 'generic/platform=iOS' build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -derivedDataPath /tmp/lutcalc-inverse-sim-dd -destination 'generic/platform=iOS Simulator' build
```

三条命令均退出码 0。日志 SHA-256 依次为：

- macOS：`1b506994358513517852c3363ceb68603d53445bba5e6f286371a70ebf7ec633`
- iOS generic：`4061109fa869fc279d401a292c1e77689f988078d5f85a427ec1416f9687b209`
- iOS Simulator generic：`b919b2abf898cbbd7b188bb8e4c4aa07b3ec074199629a9cdf269151c4d09192`

实际产物为：

- `/tmp/lutcalc-inverse-mac-dd/Build/Products/Release/LUTCalcMac.app`
- `/tmp/lutcalc-inverse-ios-dd/Build/Products/Release-iphoneos/LUTCalcIOS.app`
- `/tmp/lutcalc-inverse-sim-dd/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`

三个 App 包均未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm` 或 `.labin` 文件。未执行实体设备、UI、Finder、Files 或签名发布验收。

## 未覆盖与状态

本阶段只闭合 FULL-05 的项目／批次／导出接线子集，不等于 FULL-05 或 FULL-07 完成。仍未完成：完整 TF/颜色分离和重建、分析元数据方向／量化兼容、9 个内置资源与 45 个直接查表项的算法台账、任意 3D 逆、多解报告、目标软件互操作、真实 iPhone 11 数值／性能、文件后端和最终发布清单。Goal 保持 active。
