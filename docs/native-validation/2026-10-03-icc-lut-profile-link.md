# 2026-10-03 ICC LUT profile linking 非 UI 验收

## 范围

本阶段补齐 H13 的有限 ICC LUT profile linking 子集。两个用户提供的 RGB profile 通过 D50 PCS `XYZ ` 连接：源 profile 读取 `A2B0`，目标 profile 读取 `B2A0`。只接受显式 `relativeColorimetric`，并限制为三通道、16 位 `mft2` 以及 16 位 CLUT 的 `mAB`／`mBA`。本阶段不改变最终生成路径的 `Double` 精度，也不打包任何 profile、厂商 LUT 或采样表。

## 契约与实现

- 新增 `ICCLUTProfileLink`，将源 RGB 编码转换为 PCS XYZ，再交给目标 profile 的逆向 LUT 转换。
- `mft1`、非 `XYZ ` PCS、非 RGB profile、其他 rendering intent 和非法方向明确拒绝。
- `A2B0` 只接受 `mAB ` 载荷，`B2A0` 只接受 `mBA ` 载荷；方向错配不会被当作可用 profile。
- synthetic identity profile 只用于契约测试，不进入应用资源；用户导入的 profile 数据只在初始化时解析。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ICCLUTProfileLinkContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ICCLUTProfileLinkContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-link-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-link-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-link-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-icc-link-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-icc-link-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-icc-link-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向执行 4 项，0 失败。
- Release 定向执行 4 项，0 失败。
- 当前 LUTKit Release 全量执行 606 项，0 失败；其中 LUTFormats 的 2 项既有 `.labin`／NCP 外部夹具按设计跳过。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出 0，并生成实际 App 包。构建日志中的 CoreSimulator 内存初始化警告不改变 generic 构建结果，也不构成模拟器交互证据。
- 原生源码边界审计通过：147 个 Swift 源文件；三个实际 App 包资源审计通过，没有所列 LUT／脚本资源或 WebKit／JavaScriptCore 直接链接。

日志与结果包位于 `docs/native-validation/artifacts/2026-10-03-icc-lut-profile-link/`。

| 文件 | SHA-256 |
| --- | --- |
| `lutcalc-icc-lut-profile-link-release-20261003.log` | `878a61b5c28e43cd09c13625b753e1129fa1781f2184ff644ded3e5cddf13152` |
| `lutcalc-icc-lut-profile-link-full-release-20261003.log` | `43736fa307a5dd05114f67fa0229eec7735aaab32a16ff782b308dff6128dfc1` |
| `lutcalc-icc-link-mac-build-20261003.log` | `a5d127d60b6279dc8717538c697665373f6f30427023f73be7b403f2e653baf8` |
| `lutcalc-icc-link-ios-build-20261003.log` | `145ae44328815d9df0aad52814c398c9e3df49ada2d95c248654b3d4bd55bcfa` |
| `lutcalc-icc-link-sim-build-20261003.log` | `d910b5747ff4c477df2fff95f2d23f5a87a513cc2bb5e778c2306101444e9a0b` |
| `lutcalc-icc-link-source-audit-20261003.log` | `7ff3c5fc31367b2d31bf3a67fb4a8fe3f8e7bcec4b534b62e0812006528b1f14` |
| `lutcalc-icc-link-bundle-audit-20261003.log` | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

## 未覆盖范围

这只是 H13 的有限 LUT profile linking 子集。尚未完成完整 ICC profile 类型、任意通道数、`mft1` PCS XYZ、其他 rendering intent、黑点补偿、gamut mapping、设备像素布局、profile 白点和色彩管理系统的独立参照，也没有接入项目 schema、跨平台 profile 参照或目标调色软件往返。真实 iCloud／File Provider、实体 iPhone 11 性能、UI、签名发布和 `docs/native-validation/full-scope-acceptance.json` 仍未完成，Goal 保持 active。
