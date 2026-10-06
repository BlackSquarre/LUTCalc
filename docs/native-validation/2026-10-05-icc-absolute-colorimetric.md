# 2026-10-05 ICC absolute colorimetric matrix/TRC 子集验收

## 范围

本轮只验证已有 RGB matrix/TRC ICC linking 对 `absoluteColorimetric` 的受限子集。源和目标 profile 必须都是 RGB/`XYZ ` matrix/TRC，且 `wtpt`（ICC `mediaWhitePointTag`）在既有 `2e-12` 相对容差内一致。白点不一致、LUT profile、PCS `Lab ` 和其他 rendering intent 继续拒绝。

## 公式依据

依据 ICC.1:2022-05：

- §6.2.3 说明 ICC-absolute colorimetric 使用经过适应的 nCIEXYZ，不改变其绝对值；在没有专用 `DToB3`/`BToD3` 时，可由 media-relative 变换和媒体白点比例得到。
- §6.3.2.2 公式 (1)–(6) 给出 PCS media-relative 与 ICC-absolute 的逐通道比例；Annex D §D.6.1 公式 (D.7) 给出从现有 media-relative PCS 值得到 ICC-absolute 值的比例。
- 在源、目标媒体白点相同的限定下，源侧 absolute→relative 与目标侧 relative→absolute 的比例相消。因此 matrix/TRC 的现有 PCS XYZ 连接可以复用；这不推导白点不一致或其他 profile 类型的实现。

公开来源：<https://www.color.org/specification/ICC.1-2022-05.pdf>。

## 契约与实现

先行契约在旧实现上对 absolute intent 预期失败，随后实现：

- 相同媒体白点的 identity matrix/TRC synthetic profile，独立预期为输入各通道平方；
- 媒体白点不一致时返回 `mismatchedPCSWhitePoint`；
- `ICCRGBProfileLink` 对 LUT 与 PCS `Lab ` 的 absolute intent 返回 `unsupportedRenderingIntent`；
- relative intent、既有 RGB/XYZ LUT、Lab 路由和损坏 profile 拒绝边界保持不变。

实现只保存 intent 和 profile metadata，不加入厂商 profile、LUT、旧 `.labin` 或等价采样表。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

定向 Release：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCMatrixTRCContractsTests|ICCRGBProfileLinkContractsTests|ICCLUTProfileLinkContractsTests|ICCMFTContractsTests|ICCMABContractsTests|ICCPCSXYZContractsTests|ICCLabPCSContractsTests'
```

结果：ICC 相关定向套件 94 项，0 失败；`ICCMatrixTRCContractsTests` 20 项，`ICCRGBProfileLinkContractsTests` 12 项。日志为 `artifacts/2026-10-05-icc-absolute-colorimetric/icc-release.log`，SHA-256：`334a83331bcf6cf8bc04621ad8d0862d07edbf80ceb2a38592d1478153ff71f5`。

当前 Swift Release 全量回归：8 个测试包，793 项执行，0 失败；`LUTFormats` 的 2 项既有外部夹具按原规则跳过，`LUTAnalysis` 为 66 项。日志 `artifacts/2026-10-05-icc-absolute-colorimetric/full-release.log`，SHA-256：`fd5f70add760cccfd4a774b89f69fcb1099875c9b37e0da7e5c1993233be2730`。

三平台未签名 Release 构建均退出码 `0`：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcICCAbsoluteMac20261005 \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcICCAbsoluteIos20261005 \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcICCAbsoluteSimulator20261005 \
  CODE_SIGNING_ALLOWED=NO build
```

日志 SHA-256：

- macOS：`6f7456b0a16e8187a1737bf75e807936813087fd6b4dc1abf3e71542f65d4e20`
- iOS：`05933e65b28e719955b01bb5d89277e05ccc12092f950837dc6ad9673e37f18a`
- iOS Simulator：`7379005e1529a8e92af2cc95c937ea85a37ce1f4f51841298b7541feba9642f8`

源码与契约的 SHA-256：

- `ICCMatrixTRCProfileLink.swift`：`074daf24354fa93ea35a219d33dfc2ca6aeabc50c2bdb49a11ade8064dc48725`
- `ICCRGBProfileLink.swift`：`7a468bf64dac33cb1fffa9b7ab6224689a99d0a57043ee7a2fccbe4a4559842d`
- `ICCMatrixTRCContractsTests.swift`：`8fd6ce672c42fe56ca5a9a343c656f783fd1937f201df1c2e5b9bebdc7e5577f`
- `ICCRGBProfileLinkContractsTests.swift`：`46f8582f498b6404951588bef25ab1033710cfe6dae6ed29b94d0c681fd714e9`

## 未覆盖

这只关闭相同媒体白点的 matrix/TRC absolute linking 子集，不代表完整 ICC。仍未完成：不同媒体白点的比例连接、`DToB3`/`BToD3`、非 synthetic 真实 profile 逐码参照、完整 profile 类型／通道、perceptual／saturation、LUT/Lab absolute intent、黑点补偿、gamut mapping、系统 ColorSync、HDR/EDR、跨平台独立参照和目标调色软件往返。

Goal 继续保持 `active`。
