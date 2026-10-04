# 2026-10-04 ICC relative colorimetric 标签 fallback 验收

## 范围

本轮只闭合 ICC.1:2022 第 8.10.2 条在现有 RGB、D50 PCS `XYZ ` 三通道 LUT linking 子集中的标签选择：relative colorimetric 优先尝试 `A2B1`／`B2A1`，当处理元素类型或已明确不支持的编码不可用时回退到 `A2B0`／`B2A0`。没有扩展 profile 类型、其他 rendering intent、黑点补偿、gamut mapping、系统 ColorSync 或 UI。

## 实现与契约

- `ICCLUTProfileLink` 对 source 的 `A2B1`／`A2B0` 和 target 的 `B2A1`／`B2A0` 按优先级尝试。
- 只有 `.unsupportedTagType` 与 `.unsupportedEncoding` 继续尝试低优先级标签；损坏标签、长度错误、域错误、非有限结果和 profile 校验失败仍直接失败，不被 fallback 隐藏。
- 契约覆盖 `mft1` 不支持时回退到 `mft2`、8-bit PCS XYZ `mAB/mBA` 编码不支持时回退到 16-bit、intent-1 优先，以及 malformed intent-1 标签拒绝。

## 实际验证

工具链：Xcode 27.0 (27A266a)，Swift 6.4，arm64 macOS。

定向 Debug：

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter 'ICCLUTProfileLinkContractsTests|ICCRGBProfileLinkContractsTests|ICCMFTContractsTests|ICCMABContractsTests|ICCPCSXYZContractsTests|ICCLabPCSContractsTests|ICCMatrixTRCContractsTests'
```

结果：69 项通过，0 失败。日志及 SHA-256：
`artifacts/2026-10-04-icc-relative-intent-fallback/icc-debug.log`（`0fc8d3920b28be1b52c17153a8c031fbcb837ea13339cdcc76ed5c84fcbe574c`）。

LUTKit 全量 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包全部通过，共执行 774 项，其中 2 项既有外部夹具按原规则跳过，0 失败。日志 SHA-256：
`ac1210dbfbeedbcaf6bc2e78e31915faed805ce1c96db72b7b9b4486a1bc90ef`。

三平台 Release 构建均退出码 `0`：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/LUTCalcICCFallbackMac20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/LUTCalcICCFallbackIOS20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/LUTCalcICCFallbackSim20261004 CODE_SIGNING_ALLOWED=NO build
```

- macOS arm64：日志 SHA-256 `8fd3448f0e5d1568978f45f5c7cc70940d7e631be1c226a9b95a3874de67f07b`；
- iOS generic：日志 SHA-256 `4676445a6a27b8946ea51c6886878f928d3bca4b5bc513ec285e00b38b442cad`；
- iOS Simulator generic：日志 SHA-256 `17acc18bf5f32a0ba14c5099f16fc47b04897887c6c029a0a963e29836b5edcd`。

完整日志保存在同名 artifacts 目录。

## 未覆盖范围

本轮不代表完整 ICC 完成。仍未完成：真实非合成 profile 逐码独立参照、profile class／通道数其余组合、perceptual／saturation／absolute intent、黑点补偿、gamut mapping、系统色彩管理、HDR/EDR、跨平台独立参照、目标调色软件往返、项目接入、实体 iPhone 11 性能和签名发布。真实 `docs/native-validation/full-scope-acceptance.json` 仍不存在，Goal 保持 `active`。
