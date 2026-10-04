# 2026-10-01 图像导入文件协调阶段验收

## 修复范围与契约

审查发现 `NativeUserLUTLoader` 已使用 `NSFileCoordinator`，但 `NativePreviewImageLoader` 只取得 security-scoped 授权后直接解码 URL，未把图像解码和源 ICC 检查纳入文件协调。File Provider 或其他遵守文稿协调的客户端替换文件时，该入口缺少读取边界。

先增加三项契约：协调读取拒绝后传播原错误并释放授权；协调解码返回取消错误后释放授权；实际协调解码过程中授权保持有效，且系统生成 PNG 的原始整数码值保持精确。旧代码因缺少 `CoordinatedPreviewImageDecoding` 协议按预期编译失败（退出 `1`），随后完成实现。

新增 `NativeCoordinatedPreviewImageDecoder`，在一个 `NSFileCoordinator` 读取回调内使用提供商返回的 URL 完成 ImageIO 解码及源 ICC 检查。协调错误原样传播，读取前后检查取消；加载器在成功、错误和取消路径释放已取得的授权。最终生成路径、网格、位宽、插值与误差门槛没有改动。

## 实际命令与结果

工具链：Xcode 27.0（27A266a），macOS arm64。命令从仓库根目录执行。

```sh
swift test --package-path Native/Packages/LUTKit --filter SecurityScopedLoaderContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcImageCoordMacOct1DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcImageCoordIOSOct1DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcImageCoordSimOct1DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcImageCoordMacOct1DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcImageCoordIOSOct1DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcImageCoordSimOct1DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

- 定向 Debug：11 项执行，0 失败，退出 `0`。
- 全包 Release：345 项执行，0 失败，2 项既有可选 `.labin` 和公开 NCP 实样夹具跳过，退出 `0`。新增三项均执行并通过。
- 三平台 Release 构建及源码、三个实际 App 包审计均退出 `0`；构建采用 `CODE_SIGNING_ALLOWED=NO`，不属于发布签名验收。
- PNG 为 2×1、8-bit RGBA；测试检查的 `64/255`、`128/255`、`255/255` 与 alpha `128/255` 精确相等，归一化误差为 `0`。没有把该夹具解释为新的精度提升或完整图像格式验收。

## 证据与哈希

实际 stdout/stderr 已保存到 [证据目录](artifacts/2026-10-01-image-coordination/)。本工作包使用 Swift Package XCTest 日志作为结果证据，没有设备 XCTest 结果包。

| 文件 | SHA-256 |
| --- | --- |
| 先失败日志 `lutcalc-image-coordination-red-20261001.log` | `b68989354f6f7bc0dfa54463e7e03e0eb58a2e194f3fd0ba41d3158da9cc3fd1` |
| Debug 定向日志 | `5a474cae0ef1eb12da729bd4564bdc575b96cf1c536a8409ba6254f84d469f6d` |
| Release 全包日志 | `e38cb655e7ca432e13ecc662566040e247f1c12e28af9a0d6d1cbf919758533c` |
| 三平台构建日志（各为空） | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| App 包审计日志 | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |
| 源码审计日志 | `b23573e4983b4b43b41e308c046307c3c74f938c6c34cf64e1d4afa7845be4dd` |
| `ProjectSampleSession.swift` | `0f616a9b823608df524ce929c380993189475a24cbae164f2d66ecf7721e8b7c` |
| `SecurityScopedLoaderContractsTests.swift` | `97c57100d03d7cdf1dd01d79d7dd5336cbe5b336dad8c351f5c6e9f9eff3b4c6` |

## 未覆盖与判定

该工作包完成图像导入的协调读取接线、注入式失败/取消契约和本地实际 ImageIO 读取。注入的拒绝不能代替真实 iCloud/File Provider 授权失效，注入的取消错误不能代替 App 后台恢复；本轮没有测量协调等待时间、实际提供商替换竞争或非协作写入竞争。Finder 默认关联、iPad 旋转、多窗口、完整 ICC/HDR/EDR/OOTF、第三方软件往返、性能预算和发布签名仍未完成。H08/H13 与 FULL 项不因本次阶段验收勾选；全量清单保持缺失，Goal 保持 active。
