# ICC PCS Lab 编解码非 UI 子集验收

日期：2026-10-03

## 范围

本轮只处理 ICC PCS Lab 的公开编码边界，不涉及界面、预览叠层、目标调色软件或完整 profile linking。新增 `ICCLabPCS`，依据 ICC.1:2022-05 §10.15–§10.16 实现：

- 8 位 PCS Lab：L* 使用 `0...255`，a*/b* 使用加 128 的无符号编码；
- 16 位 PCS Lab：L* 使用 `0...65535`，a*/b* 从 `[-128,127]` 缩放到无符号 16 位；
- 编解码与 LUTCore 的 D50 `CIELABColor`／`XYZ64` 连接；
- 超出 PCS 合法域、错误通道数和非有限输入明确拒绝，不静默 clamp；
- 保持 `Double` 计算和既有数值门槛，不新增内置采样表或 ICC 资源。

来源标识保存在源码 `ICCLabPCS.referenceURL`：`ICC.1:2022-05 §10.15–§10.16`。

## 契约测试

先添加 `ICCLabPCSContractsTests`，再实现源码。覆盖 4 项：

1. 8 位黑、白和极端 a*/b* 编码逐值核对；
2. 16 位 a*/b* 缩放及编码后逐值回读；
3. D50 白点经 PCS Lab 编解码到 XYZ 的独立边界核对；
4. 错误长度、越界 L*/a*/b* 和非静默拒绝。

先行失败命令：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCLabPCSContractsTests
```

结果为编译失败，原因是 `ICCLabPCS` 尚不存在；原始失败输出未覆盖工作区文件。

## 实际验证

工具链：Xcode 27，Swift 6，macOS 27 SDK，Apple Silicon arm64。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCLabPCSContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ICCLabPCSContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-pcs-lab-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-pcs-lab-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-pcs-lab-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

结果：

- Debug 定向 4 项，0 失败；
- Release 定向 4 项，0 失败；
- Release 全量 8 个测试包共 563 个测试，0 失败；LUTFormats 的 2 个既有外部夹具按设计跳过；
- macOS、iOS generic、iOS Simulator 未签名 Release 构建退出码均为 0；产物分别为 `/tmp/LUTCalc-icc-pcs-lab-mac-20261003/Build/Products/Release/LUTCalcMac.app`、`/tmp/LUTCalc-icc-pcs-lab-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app` 和 `/tmp/LUTCalc-icc-pcs-lab-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`；
- 三个 App 包未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m` 或 `.mm` 资源；
- 并行构建日志出现 CoreSimulator 服务的内存／订阅告警，但三个 `xcodebuild` 进程均以 0 退出，App 包实际存在。该告警不计作模拟器交互证据。

日志 SHA-256：

```text
Debug 定向       39b38d0dc701acaba6ec03ae9735a7376d7e90f847a329552bdd489ea834c3c7
Release 定向     8fe1cbd353d4ba8a7c73f3cabe4266beb09426453e0765e15c8119c71b80584d
Release 全量     945bc30c58cba5078dc8b16d4f8cdbc96849b8780386db7dd6c1a5ee5dce4f5e1
macOS 构建       985bc30c58cba507dc8b16d4f8cdbc96849b8780386db7dd6c1a5ee5dce4f5e1
iOS 构建         ab84cd3f5b610d8e27c114d07e504489ffae40ddc075759e70d92afaf5d5414c
模拟器构建       48153b74fdc6f04d4a5437c70b3ad16ae485823cbaa52d6666fea747b8cd34f1
```

## 未覆盖范围

本轮不声称完成 H13 或完整 ICC。仍未处理：`Lab ` PCS profile 的 `mAB/mBA`／`mft1/mft2` 端到端接入、完整 profile 类型和通道、其他 rendering intent、黑点补偿、gamut mapping、像素布局、跨平台独立参照，以及完整 RGB↔Lab profile linking。UI、设备、第三方软件、性能、签名发布和 `full-scope-acceptance.json` 仍保持未完成。
