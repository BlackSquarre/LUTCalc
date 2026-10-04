# 2026-10-03 ICC profile class 与通道元数据非 UI 验收

## 范围

本阶段只补用户导入 ICC 的头部结构摘要，不接入 UI、系统色彩管理或新的颜色转换。依据 ICC.1:2022-05 的 profile header 字段，`ICCProfileValidator` 现在：

- 读取 offset 12 的 profile/device class；历史测试夹具将该字段全部置零时保留 `nil`，不会伪造 class。
- 对已填充的 class 字段执行四字符签名校验，非签名字节返回 `invalidProfileClass`。
- 根据 color space signature 派生标准通道数：`RGB ` 为 3、`CMYK` 为 4、`GRAY` 为 1，以及已有标准三通道和 `nCLR` 形式；未知签名保持 `nil`。
- 保留原有 profile 字节、标签 payload 和 Double 转换语义，不保存或采样任何内置 LUT。

## 先行契约

新增 3 项 `PreviewContractsTests`：

1. 零填充旧夹具返回 `profileClassSignature == nil`，RGB 通道数为 3。
2. `mntr`、`CMYK`、`Lab ` 头部读取为 class `mntr`、4 通道和 Lab PCS。
3. 非 ASCII/ICC 四字符 class 被拒绝为 `invalidProfileClass`。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter PreviewContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter PreviewContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-header-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-header-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-header-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-icc-header-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-icc-header-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-icc-header-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向 29 项通过，退出码 0。
- Release 定向 29 项通过，退出码 0。
- Release 全量 Swift 回归通过，退出码 0；已有两个外部夹具仍按设计跳过。
- macOS、iOS generic、iOS Simulator Release 构建均退出码 0。日志含 CoreSimulator 内存初始化警告；该警告不影响构建，也不构成模拟器交互证据。
- Swift 源码边界审计和三个实际 App 包资源审计均退出码 0。

结果目录：[artifacts/2026-10-03-icc-header-class](artifacts/2026-10-03-icc-header-class)。

关键日志 SHA-256：

- `debug-targeted.log`：`173f84492e586670fed89cf661a01417ea426c77541cff34a639c71cdf629558`
- `release-targeted.log`：`15000ef8338eecf1b07764690326ac9eacfbaefffcd604be545ca3ad6ef01a9f`
- `full-release.log`：`d442f2caecfb373d8795994167279d841821e8049a77d35c4ff627c49684419e`
- `macos-build.log`：`57a09ab4250d5385adc2bb353ca3feeb05a1cb7c96f9130ba550e23d55d11e0a`
- `ios-build.log`：`112950d4f2c15f8a5b3a0a34e93c4361d9b26995c92a2b589e9777bd7206af94`
- `sim-build.log`：`f22c4fc29ad33b05511f5e36352c7e9b4463b5ce6669bd2f4a4b59110f3502d6`
- `source-audit.log`：`9b26b6128e135d54bd2f6de638d7d3583c21d0fef5f13d2dc8c3dbc26505dc34`
- `bundle-audit.log`：`5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f`

## 未覆盖范围

profile class 与通道数摘要不等于完整 ICC。完整 profile class 语义、PCS 转换、perceptual/saturation/absolute intent、黑点补偿、gamut mapping、多通道转换、所有像素布局、跨平台独立参照、项目接入、第三方往返、HDR/EDR、真机性能和签名发布仍未完成。UI 按当前要求继续暂缓；没有创建 `full-scope-acceptance.json`，Goal 保持 active。
