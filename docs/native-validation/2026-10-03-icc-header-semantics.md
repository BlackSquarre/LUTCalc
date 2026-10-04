# 2026-10-03 ICC 头部语义枚举非 UI 验收

## 范围

本阶段只补用户导入 ICC 头部的可追溯语义摘要，不接入界面、系统色彩管理或新的转换路径。`ICCProfileValidation` 现将已知 profile class 映射为 `scnr`、`mntr`、`prtr`、`link`、`spac`、`abst`、`nmcl`，并将 PCS 映射为 `XYZ ` 或 `Lab `。原始四字符仍独立保留：格式合法但未知的未来 class 继续保留 raw signature，零填充历史夹具继续保持未知，不猜测语义。

## 契约

- 已知 `mntr` class 和 `Lab ` PCS 能恢复对应枚举。
- `link`、`spac` 等已知 class 能保留原始签名并恢复语义。
- 合法但未知的 `futr` class 保留 raw signature，语义枚举为 `nil`。
- 非法 class 字节仍拒绝；历史零填充夹具不被误判为合法 class。
- 该改动不保存或采样 ICC LUT payload，也不改变既有 matrix/TRC、mft、mAB/mBA 或显式 linking 的 Double 数值路径。

## 实际验证

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter PreviewContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter PreviewContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-header-semantics-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-header-semantics-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-header-semantics-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-icc-header-semantics-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-icc-header-semantics-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-icc-header-semantics-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向 `PreviewContractsTests` 通过，退出码 0。
- Release 定向 `PreviewContractsTests` 通过，退出码 0。
- Release 全量 Swift 回归实际执行 617 项，0 失败；既有 `.labin` 与 NCP 外部夹具各 1 项继续按设计跳过。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出码 0，并生成实际 App 包。
- 原生源码边界审计和三个实际 App 包资源审计均退出码 0。

日志、状态和 SHA-256 归档于[`artifacts/2026-10-03-icc-header-semantics`](artifacts/2026-10-03-icc-header-semantics)。并行构建期间出现的既有 CoreSimulator 内存／订阅警告不改变构建退出码，也不构成设备或 UI 证据。

## 未覆盖范围

这只闭合 ICC 头部 class／PCS 的语义摘要，不代表完整 ICC profile 类型、任意通道数、其他 rendering intent、黑点补偿、gamut mapping、系统色彩管理、跨平台独立参照、项目接入或第三方软件往返。HDR/EDR、真实 provider、设备性能、签名发布和 `full-scope-acceptance.json` 仍未完成；UI 按当前要求继续暂缓，Goal 保持 active。
