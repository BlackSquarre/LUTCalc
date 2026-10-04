# 2026-10-03 3DL 流式生成携带非线性 shaper 非 UI 验收

## 范围

本阶段补齐 FULL-06 中 3DL 非线性 shaper 的流式生成接口。此前的解析器和 `ThreeDLWriter.serialize` 已能保存、量化和直接序列化可验证的 shaper，但 `FileCubeSink` 与 `NativeExportService` 不能携带 shaper，导致生成服务无法产出带 shaper 的 3DL。本阶段没有执行 UI、Finder/Files、真机或目标调色软件互操作。

## 契约先行

- 新增流式契约：3³ 3DL 生成必须在每个文件网格坐标先应用独立 1D shaper，再执行 `TransformPlan`，并在头部保存同一个 shaper。
- 新增拒绝契约：为 `.cube` 等非 3DL 输出传入 shaper 必须明确失败，不能静默丢弃元数据。
- 首次实现前运行定向测试时，测试因 `NativeExportService` 和 `NativeExportError` 尚未提供而编译失败；该次命令未通过 `tee` 保存独立日志，原始终端输出显示为 `cannot find 'NativeExportService' in scope` 和 `cannot find type 'NativeExportError' in scope`。修复后的失败边界未被改写成通过证据。

## 实现

- `LUTGenerationRequest` 增加可选 `inputShaper` 及预构造的线性 `PreparedCubeSampler`；3D worker 在 `TransformPlan` 前按文件网格坐标应用 shaper。
- `FileCubeSink` 增加 `threeDLShaper`，把 shaper 写入 3DL 头；原有轴序、Double 计算、12-bit 输出量化、Lustre/Kodak 头尾和事务提交保持不变。
- `NativeExportService.generate` 增加 `threeDLShaper` 参数；非 3DL 明确返回 `threeDLShaperRequiresThreeDL`，请求对象与显式参数不一致时返回 `conflictingThreeDLShaper`。
- 使用可按 10-bit 输入精确量化的 `[0, 256/1023, 1]` 三节点曲线作为非线性测试夹具；没有新增内置 LUT、厂商采样表或外部计算内核。

## 实际命令与结果

工具链：Xcode 27.0、Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter 'ThreeDLExportContractsTests|ThreeDLServiceContractsTests'
swift test -c release --package-path Native/Packages/LUTKit --filter 'ThreeDLExportContractsTests|ThreeDLServiceContractsTests'
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-3dl-stream-shaper-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-3dl-stream-shaper-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-3dl-stream-shaper-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-3dl-stream-shaper-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-3dl-stream-shaper-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-3dl-stream-shaper-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向：`LUTSharedUITests` 中 6 项、`LUTJobsTests` 中 5 项，共 11 项，0 失败。
- Release 定向：同一 11 项，0 失败。
- Release 完整：`LUTSharedUITests` 134、`LUTProjectTests` 35、`LUTPreviewTests` 63、`LUTJobsTests` 45、`LUTFormatsTests` 56（2 项既有外部夹具跳过）、`LUTCoreTests` 174、`LUTCatalogTests` 20、`LUTAnalysisTests` 32，共 559 项，0 失败。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均生成实际 App 包。日志中已有 CoreSimulator 内存／订阅警告，但三个命令均生成目标包；没有把这些构建当作设备或 UI 验收。
- 原生源码边界审计通过：138 个 Swift 文件；三个实际 App 包资源审计通过，没有所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

结果日志 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-3dl-stream-shaper-debug-20261003.log` | `06154852d93b07cca6801c001974bae3e933b0d3d819d1669043d8d86708568f` |
| `/tmp/lutcalc-3dl-stream-shaper-release-20261003.log` | `106f88e27005c8095323496604153c733c0d82d479075a60795ddf6c655d7cac` |
| `/tmp/lutcalc-3dl-stream-shaper-full-20261003.log` | `1f0f29a6a867258cbdace64d8958abd758d50c972944b036a73ff1210c2d4dad` |
| `/tmp/lutcalc-3dl-stream-shaper-mac-build-20261003.log` | `537ceaa244fa3f47e3de56eef1a626c6fb7c8c0a511c9c4d8cf02367694630d4` |
| `/tmp/lutcalc-3dl-stream-shaper-ios-build-20261003.log` | `04380a0c839204423ea9c7bc83dce32a45166a6c728a6e1c92f3abae37d40a6e` |
| `/tmp/lutcalc-3dl-stream-shaper-sim-build-20261003.log` | `4edfb7e0e3ebe8eb57e03368b036625ed8a8b3f2ba898d1288da34a632046610` |
| `/tmp/lutcalc-3dl-stream-shaper-source-audit-20261003.log` | `bede37010d812ba484d071a23583620a303a7f1422a93a88e6739f9223643751` |
| `/tmp/lutcalc-3dl-stream-shaper-bundle-audit-20261003.log` | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

## 未覆盖范围

本阶段只证明原生流式接口的参数传递、shaper 应用和本地解析读回。尚未证明第三方调色软件互操作、其他设备布局、NCP 写出、全格式批量往返、File Provider／iCloud 故障、性能预算、签名发行或真实全量清单。此前阶段记录中“流式生成接口尚无 shaper 参数”的描述是本阶段前的历史状态；FULL-06、H08/H12/H14 和 Goal 仍保持未完成，`docs/native-validation/full-scope-acceptance.json` 未创建。
