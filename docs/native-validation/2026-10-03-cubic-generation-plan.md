# 2026-10-03 严格 1D cubic 反求生成计划验收

## 范围

本阶段只推进非 UI 的 FULL-05 子集。严格单值的旧 `LUTSpline` 1D cubic 反求已经有独立数值验收，本阶段把它冻结为显式 `ImportedLUTInversePlan`，接入 3D `LUTGenerationRequest`。每个生成网格坐标按 R/G/B 三个独立 cubic 反求后再进入 `TransformPlan`。

不接入项目 schema、项目持久化、曝光批次、1D 导出服务或所有导出服务；不从任意 3D LUT、颜色分节或采样表推断逆变换。非 `tricubicLegacyV1`、常值段、平段、导数换向、多根和域外目标均保持明确失败。

## 先行契约与实现

- 先新增 3 项 `LegacyCubicInverseGenerationContractsTests`，首次运行因缺少 `ImportedLUTInversePlan`、请求参数和冲突错误而编译失败；该红灯日志保留在本轮命令输出中。
- 新增 `ImportedLUTInversePlan`，构造时冻结三条 `LegacyCubicCurve1D` 并检查全域 cubic 导数临界点；每个节点只执行已冻结曲线的 Brent 反求。
- `LUTGenerationRequest` 新增 `inputTransferInverse`；它与已有 `inputShaper` 互斥，避免隐式决定两个输入变换的先后关系。没有该字段的请求保持原字节和数值路径。

## 实际工具链、命令与结果

工具链：Xcode 27.0、Swift 6 语言模式、macOS arm64。

定向 Debug：

```sh
swift test --package-path Native/Packages/LUTKit --filter LegacyCubicInverseGenerationContractsTests
```

结果：3 项通过、0 失败。

定向 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter LegacyCubicInverseGenerationContractsTests
```

结果：3 项通过、0 失败。最终日志 `/tmp/lutcalc-cubic-generation-plan-release-20261003-r2.log`，SHA-256 `6e8f803e339ab3a2643858fe518d52c6bf770df5e6b26091cb325eeeae0849f2`；初始定向日志 `/tmp/lutcalc-cubic-generation-plan-release-20261003.log` 的 SHA-256 为 `25d009831a9e727b7a1f0ffc8b2bb5c5fffd61e40bc2e95f2920693dc80f6594`。

Release 全量：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包合计实际执行 579 项、0 失败（SharedUI 135、Project 42、Preview 72、Jobs 48、Formats 56、Core 174、Catalog 20、Analysis 32）；LUTFormats 的既有 `.labin` 和 NCP 外部夹具各 1 项按设计跳过。最终日志 `/tmp/lutcalc-cubic-generation-plan-full-release-20261003-r2.log`，SHA-256 `0475877447e01cc0eff3fe0e13230c541fb66365d2e8cf02dc5ab8f297e0e49b`；初始日志 `/tmp/lutcalc-cubic-generation-plan-full-release-20261003.log` 的 SHA-256 为 `14de35b630819ad90debae0553ec44f07d2ae5b0d842dab1405db78e3767e0da`。

三平台 Release 构建：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/LUTCalc-cubic-generation-plan-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-cubic-generation-plan-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-cubic-generation-plan-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

三条命令均退出码 `0`。日志 SHA-256 分别为 macOS `7666a9be00cd79fbc0714aa8c97605ae5f7adcb825b954abdd3a271e336ac9d8`、generic iOS `30ffc9e9a75b769ce2014dc99c1e3053ae32bcc489419cf57fc74163bcb57efa`、iOS Simulator `99406fdd85077d00c3fefcb4b74508bdc1d381f7aca944168eee66b1f0907b9a`。产物分别为 `/tmp/LUTCalc-cubic-generation-plan-mac-20261003/Build/Products/Release/LUTCalcMac.app`、`/tmp/LUTCalc-cubic-generation-plan-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app` 和 `/tmp/LUTCalc-cubic-generation-plan-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`。三个 App 包均未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm` 或 `.labin` 文件。

## 独立数值参照

契约曲线样本 `[0, 0.25, 0.75, 1]`、unit domain 的中点目标由独立 Hermite 参照计算。生成 3³ 网格的中心节点目标为 `0.5`，逐通道反求结果与 `0.5` 的绝对误差不超过 `2e-12`。此前 80 位 Decimal 的 `t=0.37` 参照与 1D cubic 220 点冻结参照仍作为算法证据，本阶段没有改动插值、网格、Double 或阈值。

## 未覆盖与结论

- 这只证明 3D 生成请求的严格 1D cubic 逆入口，未证明项目持久化、批次快照、SPI1D／ILUT／OLUT／Assimilate 等 1D 服务或全部导出服务接线。
- 组合 shaper 仍只有独立反求；完整 TF／颜色分离、重建、方向／量化元数据和任意 3D 逆仍未实现。任意 3D 逆继续显式拒绝。
- 未运行 UI、Finder／Files、实体设备、目标调色软件、File Provider、性能预算、签名或发布验收；真实 `docs/native-validation/full-scope-acceptance.json` 仍缺失，不能以本阶段结果替代全量清单。

因此 FULL-05、H07、H10、H14 以及 Goal 继续保持 active。
