# 2026-10-03 ICC RGB profile linking 统一分派非 UI 验收

## 范围

本阶段为已有的 matrix/TRC linking 与 LUT linking 增加统一 Swift 入口 `ICCRGBProfileLink`。入口只在 profile 结构已经明确时分派：两个没有对应 LUT 方向标签的 RGB/`XYZ ` profile 走 matrix/TRC；源有 `A2B0` 且目标有 `B2A0` 时走有限 LUT linking。混合形式、缺少对应方向、其他 PCS、非 RGB 和未支持的 rendering intent 均显式拒绝。

本阶段不引入系统色彩管理、Core Image、Metal、厂商 LUT 或等价内置采样表。用户 profile 只在初始化时读取并交给已有受限 CPU `Double` 路径。

## 契约与实现

- 新增 `ICCRGBProfileLink` 和统一错误类型，避免调用方根据标签自行猜测 profile 类型。
- matrix/TRC route 复用 `ICCMatrixTRCProfileLink`；LUT route 复用 `ICCLUTProfileLink`。
- 契约覆盖系统 sRGB matrix/TRC 自连接、两个 synthetic 16 位 `mft2` profile 的 LUT route、matrix/LUT 混合拒绝以及 unsupported intent 在分派前拒绝。
- synthetic profile 只存在于测试代码，不进入 App 资源。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ICCRGBProfileLinkContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ICCRGBProfileLinkContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-rgb-link-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-rgb-link-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-rgb-link-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-icc-rgb-link-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-icc-rgb-link-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-icc-rgb-link-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向执行 4 项，0 失败。
- Release 定向执行 4 项，0 失败。
- 当前 Swift Release 全量执行 610 项，0 失败；LUTFormats 的旧 `.labin` 与 NCP 外部夹具各 1 项按设计跳过。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出 0 并生成实际 App 包。CoreSimulator 初始化警告只反映当前主机的设备服务状态，不构成模拟器交互证据。
- 原生源码边界审计通过：148 个 Swift 源文件；三个 App 包资源审计通过，没有所列 LUT／脚本资源或 WebKit／JavaScriptCore 直接链接。

结果与日志位于 `docs/native-validation/artifacts/2026-10-03-icc-rgb-profile-link/`。

| 文件 | SHA-256 |
| --- | --- |
| `icc-rgb-profile-link-debug-20261003.log` | `7524fcf4618d40081d4f587f22fc11d0ba85c6c504852db48b9bc391d86cc3f2` |
| `icc-rgb-profile-link-release-20261003.log` | `ac176fc2abdeaf024fb53010e707554493d917d9d9a39f0bb5bf452b5db0ca9c` |
| `icc-rgb-profile-link-full-release-20261003.log` | `073bf94a792ce7a5630f10b29d58c33ecf26770aeb8d46bc5414b83f0e09435f` |
| `icc-rgb-link-mac-build-20261003.log` | `f081705fd469599b75f11b97631b68d892d5de9ea235a9dad52e4169da577c4e` |
| `icc-rgb-link-ios-build-20261003.log` | `590f7b2fd9df20609c57031b3a7ae13f48a2ef2f5cb44d9688198b3aa5fdcbf1` |
| `icc-rgb-link-sim-build-20261003.log` | `c885d7fa8cfd375e62255c3dfdfa6b43626c8f735f3a6136454bf3bc6e753aaf` |
| `icc-rgb-link-source-audit-20261003.log` | `9b26b6128e135d54bd2f6de638d7d3583c21d0fef5f13d2dc8c3dbc26505dc34` |
| `icc-rgb-link-bundle-audit-20261003.log` | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

## 未覆盖范围

统一入口仍只覆盖相对色度意图和 RGB/`XYZ ` profile。完整 ICC profile 类型、任意通道数、PCS Lab linking、perceptual／saturation／absolute intent、黑点补偿、gamut mapping、像素布局、系统色彩管理、跨平台独立参照、项目 schema 接入和目标软件往返仍未完成。HDR/EDR、真机性能、File Provider、签名发布和 `full-scope-acceptance.json` 也仍未完成，Goal 保持 active。
