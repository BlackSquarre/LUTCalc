# 2026-10-03 ICC 像素级显式 linking 非 UI 验收

## 范围

本阶段只补非 UI 后端边界。`ICCRGBProfileLink` 新增显式像素缓冲转换方法，调用方必须同时提供源/目标 profile、`relativeColorimetric` intent、输入 alpha 语义和输出 alpha 语义。`PreviewImageDecoder`、`CPUPreview` 和默认预览路径没有自动调用该方法，因此图像解码不会隐式执行 ICC linking。

支持范围沿用现有统一入口：RGB/`XYZ `、matrix/TRC 或有限 16 位 `mft2`／`mAB`／`mBA` LUT profile linking。其他 ICC profile 类型、rendering intent、黑点补偿、gamut mapping 和系统色彩管理仍拒绝或未实现。

## 契约先行与实现

- 直通 profile linking 仍通过 `ICCRGBProfileLink.convert(_:)`。
- 新增 `convert(_:inputAlpha:outputAlpha:)`：
  - straight 输入直接转换；
  - premultiplied 输入先按 alpha 解包，输出按请求重新预乘；
  - alpha 为 0 的样本固定输出黑色 RGB，避免隐藏色在后续边界重新出现；
  - 不改变 Double 计算精度，不写入任何 profile 或采样表资源。
- 新增契约覆盖 straight、premultiplied、透明样本和显式调用边界。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ICCRGBProfileLinkContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-explicit-pixel-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-explicit-pixel-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-explicit-pixel-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-icc-explicit-pixel-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-icc-explicit-pixel-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-icc-explicit-pixel-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向 5 项通过，0 失败。
- Release 全量 Swift 回归通过，0 失败；日志中的两个既有外部夹具仍按设计跳过（旧 `.labin`、NCP）。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出 0。
- 原生边界审计通过：148 个 Swift 源文件；三个 App 包没有所列 LUT、脚本、WebKit 或 JavaScriptCore 资源。

结果目录：[`artifacts/2026-10-03-icc-explicit-pixel-link`](artifacts/2026-10-03-icc-explicit-pixel-link)。

关键日志 SHA-256：

- `full-release.log`：`62b68b613cb2724e83c2c70655edb35dc59f72d191ee90a3cabdcecf291c3dc6`
- `debug-targeted.log`：`d24aeedba3d266611e2c3d1808463c048af83ace6c9cea69ed12a135b2294159`
- `macos-build.log`：`13dacb2aac3a9a5368e30bafd19dfa8be3b744b0b7d0f21bf69385c38a781158`
- `ios-build.log`：`a0328128182362e5ae421bd75372a9d52b5b3a7be47e7e6688a7dcedce6cb7db`
- `sim-build.log`：`0ca101576dbbb89891241dcaed13a37dd222af28277d05fa86c4ec9c0de9358e`
- `source-audit.log`：`9b26b6128e135d54bd2f6de638d7d3583c21d0fef5f13d2dc8c3dbc26505dc34`
- `bundle-audit.log`：`5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f`

## 未覆盖范围

本阶段没有把显式 API 接入默认预览、项目 schema 或系统色彩管理，也没有声称完整 ICC。其他 profile 类型／通道、PCS 和 rendering intent、黑点补偿、gamut mapping、其他像素布局、独立跨平台参照、HDR/EDR、真实 provider、实体 iPhone 11 性能、签名发布和 `full-scope-acceptance.json` 仍未完成。Goal 保持 active。
