# 2026-10-03 3DL 非线性 shaper 非 UI 验收

## 范围

本阶段处理 FULL-06 中可由现有 `CubeShaper` 模型明确表达的 3DL 非线性 shaper 子集。此前 `ThreeDLParser` 只接受按输入位深等间距生成的 identity shaper，`ThreeDLWriter.serialize` 也拒绝所有带 shaper 的 `CubeLUT`。本阶段允许单调不下降、覆盖完整输入域的显式 shaper，并在直接文本序列化时保留其输入代码。

本阶段没有改变 UI、目标调色软件互操作、File Provider、设备布局或流式 `FileCubeSink.prepare` 接口；没有把设备专用的未知 shaper 语义扩展为任意非单调曲线。

## 契约先行

- 先增加解析器契约：3 节点、2 位输入的 `[0, 1, 3]` shaper 必须保存为 `CubeShaper`，旧 `[0, 3]` identity 仍归一化为无 shaper。
- 先增加写出契约：带 `[0, 1, 3]` shaper 的 3³ `CubeLUT` 写出后再读回，shaper 与 27 个体数据节点保持一致。
- 非单调 `[2, 0]`、缺少完整输入端点、超出输入位深或无法以给定位宽精确量化的 shaper 仍拒绝。首次契约运行在实现前失败，日志保留在 `/tmp/lutcalc-3dl-shaper-debug-20261003.log`；中间一次测试字符串缺少显式换行，修正后的失败日志为 `/tmp/lutcalc-3dl-shaper-debug-20261003-r2.log`。

## 实现

- `ThreeDLParser` 验证 shaper 长度、代码范围、首尾端点和单调性；identity 仍不创建冗余 `CubeShaper`，非线性输入按输入最大代码归一化到 unit domain 并保留到 `CubeLUT.shaper`。
- `ThreeDLWriter.header` 增加可选 shaper；`serialize` 对 unit-domain、三通道相同且可按 `inputBits` 量化的 shaper 写出原始输入代码。输出代码继续使用既有 half-up 规则，网格尺寸、输出位宽、行顺序和 Lustre/Kodak 头尾不变。
- 代码仍为 Swift/Double；没有新增内置 LUT、采样表或外部计算内核。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ThreeDLContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ThreeDLContractsTests
swift test -c release --package-path Native/Packages/LUTKit
```

- Debug 定向：10 项，0 失败。
- Release 定向：10 项，0 失败；仅有既有测试警告 `#UnnecessaryEffectMarker`，与本阶段无关。
- Release 完整：8 个测试包共 551 项，0 失败；LUTFormats 的既有 `.labin` 与 NCP 外部夹具各 1 项继续跳过。完整日志为 `/tmp/lutcalc-3dl-shaper-release-full-20261003.log`。

随后串行执行三个未签名 Release 应用构建，均退出 0：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-3dl-shaper-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-3dl-shaper-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-3dl-shaper-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

构建日志中有既有 CoreSimulator 内存／设备集订阅警告，但不影响三个目标的退出码；本阶段没有启动模拟器或进行 UI 验收。

日志 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-3dl-shaper-debug-20261003-r3.log` | `a56ad0e675b5c9cc20aa53297969ae34d55905df482141db053ac9ea7b744487` |
| `/tmp/lutcalc-3dl-shaper-release-20261003.log` | `7483023e10017fffe97f06e5dee182a4c1dbe364f13789d423c831ace5d908dd` |
| `/tmp/lutcalc-3dl-shaper-release-full-20261003.log` | `fffe55fa87af190baba5f1e5891fae6b78258435095a83293a9e65628948be84` |
| `/tmp/lutcalc-3dl-shaper-mac-build-20261003.log` | `5df1ba4461d47edfa24813bf7ef7317ad91022b1b211d12a7bc00c679af91ab7` |
| `/tmp/lutcalc-3dl-shaper-ios-build-20261003.log` | `327c0e8c5b59eee6e9d95359569f4d5a7931f67915b28603841a3602ebda1464` |
| `/tmp/lutcalc-3dl-shaper-sim-build-20261003.log` | `b7bebdec3ca2ada17326ec98c9d0944a0b2c9ffd293d339f603734733365de11` |

## 未覆盖范围

本阶段只覆盖 3DL 文本解析和 `ThreeDLWriter.serialize` 的显式非线性 shaper。尚未取得厂商文件、第三方目标软件或设备往返证据；`FileCubeSink` 的流式生成请求仍没有 shaper 参数，因此不能据此声称所有导出服务都支持非线性 shaper。Lustre/Kodak 的其他设备布局、NCP 写出、完整格式批量、目标软件往返、性能与发布签名仍未完成。FULL-06、H08/H12/H14 及 Goal 继续保持未完成，`docs/native-validation/full-scope-acceptance.json` 未创建。
