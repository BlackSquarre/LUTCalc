# ICC mAB/mBA PCS Lab 接入非 UI 子集验收

日期：2026-10-03

## 范围

本轮在既有 `ICCMABTransform` 三通道 CPU 解析器上增加 `ICCMABLabTransform`，只接入用户提供的 RGB profile、PCS `Lab `、显式 `A2B0`／`B2A0` 路径：

- `A2B0`：RGB 编码值经过 mAB 管线后，按 ICC 连续无符号 PCS Lab 解释为 D50 `CIELABColor`；
- `B2A0`：D50 `CIELABColor` 编码为连续无符号 PCS Lab 后进入 mBA 管线，输出 RGB；
- profile 不是 RGB、PCS 不是 `Lab `、方向标签缺失或底层 section 非法时明确拒绝；
- 复用既有 Double 曲线、矩阵、CLUT 和严格 section 边界，不打包 ICC 表或采样资源。

## 契约与实现

先在 `ICCMABContractsTests` 增加 3 项契约，再实现：

1. mAB identity 管线 RGB→PCS Lab；
2. mBA identity 管线 PCS Lab→RGB；
3. XYZ PCS 和缺失方向标签拒绝。

先行失败为 `ICCMABLabTransform`／`ICCMABLabError` 不存在的编译失败。实现后连同原有 mAB/mBA 测试共 15 项通过。

## 实际验证

工具链：Xcode 27，Swift 6，macOS 27 SDK，Apple Silicon arm64。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMABContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMABContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-mab-lab-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-mab-lab-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-mab-lab-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

结果：

- Debug 定向 15 项，0 失败；
- Release 定向 15 项，0 失败；
- Release 全量 8 个测试包共 566 个测试，0 失败；LUTFormats 的旧 `.labin` 与 NCP 外部夹具各 1 项仍按设计跳过；
- macOS、iOS generic、iOS Simulator 未签名 Release 构建退出码均为 0，App 包实际生成于对应 `/tmp/LUTCalc-icc-mab-lab-*` 路径；
- 三个 App 包未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m` 或 `.mm` 资源；
- 构建日志出现既有 CoreSimulator 内存／订阅告警，但进程均以 0 退出；这不计作模拟器交互证据。

日志 SHA-256：

```text
Debug 定向       2d77d228028096c66c33cb63b1840602f2f5b4ee2231377fa9bda84ced611ad8
Release 定向     f325dc3ca6144c0a6124dc08b9b62f82f71f31c6e79429497861c649abe83cd7
Release 全量     73410726e9e437778482b7bbde0afe79574f7d4513d063aba72f10f740c4b268
macOS 构建       a675e7ba29266e1183a3b1e37962d1339bac7d36b5a6e7cee859e76f8b0a3235
iOS 构建         fb58e83ec35b437b905b9062a10372fc67ca881ab91d064e3c260ae388dbea7b
模拟器构建       6f36c6970c6ffa9b145d3c9d49a1a450a705e3f6bbfb2eee1f89e0bcf92f61c4
```

## 未覆盖范围

这只是 ICC PCS Lab 的 `mAB/mBA` RGB 三通道子集，不代表完整 H13。仍未处理 `mft1/mft2` 的 PCS Lab 端到端路径、非 RGB 通道、完整 profile 类型、perceptual/saturation/absolute intent、黑点补偿、gamut mapping、像素布局、跨平台独立参照、项目／生成计划接入、UI、设备、性能和发布验收。
