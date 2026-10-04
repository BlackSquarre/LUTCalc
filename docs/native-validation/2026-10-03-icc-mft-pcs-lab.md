# ICC mft1/mft2 PCS Lab 接入非 UI 子集验收

日期：2026-10-03

## 范围

本轮在既有 `ICCMFTTransform` 三通道 CPU 解析器上增加 `ICCMFTLabTransform`，接入用户提供 RGB profile 的 `mft1`／`mft2`、PCS `Lab `、显式 `A2B0`／`B2A0` 路径：

- `A2B0` 将 mft 输出的连续无符号 PCS 值解释为 D50 `CIELABColor`；
- `B2A0` 将 D50 `CIELABColor` 编码为连续无符号 PCS 值后进入 mft 管线；
- 保留既有 S15Fixed16 矩阵、输入表、CLUT、输出表顺序和 `Double` 计算；
- 非 RGB、非 `Lab ` PCS、非三通道或非法方向明确拒绝，不打包任何 ICC 采样资源。

## 契约与实现

先添加 2 项契约，再实现：

1. mft1 identity RGB→PCS Lab；
2. mft2 identity PCS Lab→RGB。

先行失败为 `ICCMFTLabTransform` 不存在的编译失败。实现后与既有 mft1/mft2 契约共 8 项通过。

## 实际验证

工具链：Xcode 27，Swift 6，macOS 27 SDK，Apple Silicon arm64。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMFTContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMFTContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter 'ICCMABContractsTests|ICCMFTContractsTests|ICCLabPCSContractsTests'
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-lab-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-lab-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-lab-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

结果：

- Debug 定向 8 项，0 失败；
- Release 定向 8 项，0 失败；
- ICC 三套定向合计 27 项，0 失败；
- 与 PCS Lab、mAB/mBA 接入一起的 Release 全量实际执行 568 项，0 失败；旧 `.labin` 与 NCP 外部夹具各 1 项按设计跳过；
- macOS、iOS generic、iOS Simulator 未签名 Release 构建退出码均为 0，三个 App 包实际生成；
- 三个 App 包未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m` 或 `.mm` 资源；
- 构建日志仍有 CoreSimulator 内存／订阅告警，但进程退出码为 0；不计作模拟器交互证据。

日志 SHA-256：

```text
Debug 定向       f8b76c1672662fe1608a37f234636e464e34245ae61c6659c92b6c1eb9ae8054
mft Release      55f382b80e6185670a2351a0c2058edbea0ed2d7fdafad9ddbe0f34265774171
ICC 合并定向     159e74cb4092e396ca914939d20172ffc5a9a3928d1e8807561e7cfe1d236774
Release 全量     38aeea408db28c133b5e7abebb124c8ea454934565c75f8982c5034707323071
macOS 构建       37b7c85b67ccf64880656291c1b8cafcc6fd3ec0d22ae81d23a5bdf2b25bafcc
iOS 构建         746dd7ed023a06012df3582130b19e384231b2b8ab4cf21f830c96ce316ac1da
模拟器构建       b9a9f2542c8c784e4c351370eacd0c6591f24d0a095bb2e129ad465f98efd795
```

## 未覆盖范围

本轮仍只是 ICC PCS Lab 的三通道 mAB/mBA/mft 子集，不代表完整 H13。完整 profile 类型和通道、其他 rendering intent、黑点补偿、gamut mapping、像素布局、跨平台独立参照、项目／生成计划接入、UI、设备、性能和发布验收仍未完成。

