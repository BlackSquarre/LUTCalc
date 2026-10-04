# HLG OOTF 标量峰值裁切逆向边界验收

## 范围

本轮只收紧已有 `HLGOOTF.displayToScene` 的标量定义域。正向 `sceneToDisplay` 在峰值处会裁切并合并多个场景值，因此标量逆在显示值等于峰值时必须拒绝，避免返回伪唯一结果。没有改变 HLG OOTF 公式、峰值、黑位、BBC 系数、标度或合法内部点。

## 契约先行与实现

先新增 `HLGOOTFContractsTests.testDisplayScalarInverseRejectsPeakClippedNonUniqueValue`，复现 nits 峰值 `1000` 和 `normalizedBy1000` 峰值 `1` 被旧标量逆接受的问题。实现将逆向检查从 `display <= peak` 收紧为 `display < peak`；黑位端点和峰值以下的逆保持原行为。

## 实际验证

工具链：Xcode 27.0 (27A266a)，Swift 6.4，arm64 macOS。

```text
swift test --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
```

结果：12 项通过，0 失败，退出码 `0`。日志 SHA-256：`4ad22fd0e7eab965c3eb74df416559915a3c308841370a25679afbe9d1fb4d49`。

```text
swift test -c release --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
```

结果：12 项通过，0 失败，退出码 0。日志 SHA-256：`cb420f2c6872d9dcec76876062912901cb668cddaddd3e5339aaf6f3070fde70`。

```text
swift test -c release --package-path Native/Packages/LUTKit
```

结果：8 个测试包通过，0 失败，退出码 0；LUTCore 237 项、LUTAnalysis 54 项等全量套件均无失败。日志 SHA-256：`c29f628781694240758874d8769011edfb221d3cdd27a1b67b332bebfe31487e`。原始日志位于[验收结果目录](artifacts/2026-10-04-hlg-ootf-scalar-clip/)。

三平台未签名 Release 编译命令均退出码 `0`，并记录 `BUILD SUCCEEDED`：

```text
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -sdk macosx -destination generic/platform=macOS -derivedDataPath /tmp/lutcalc-hlg-scalar-clip-macos-20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/lutcalc-hlg-scalar-clip-ios-20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/lutcalc-hlg-scalar-clip-simulator-20261004 CODE_SIGNING_ALLOWED=NO build
```

对应日志 SHA-256：macOS `0074a8661fb468eae7a0454934eed19d1b687bd84d0166eebf9987f88c316917`、iOS `b8b8f76237f3bb3227c784e6262459887305bde2da726a5db16169f6a1610b1c`、iOS Simulator `38890f1753a95b27521fce628cd909349585b09601ec07f7aa7c91aeb178e69b`。本记录没有进行真机或签名发行验收。

## 未覆盖范围

本项只关闭 HLG OOTF 标量峰值裁切的非唯一逆输入边界。自动峰值、参考白／黑位、四种 HDR 变体、PQ OOTF、完整 HDR/EDR、显示系统接入、查表替代、LUTAnalyst、UI、真机性能、签名发布和真实全量清单仍未完成。Goal 保持 `active`。
