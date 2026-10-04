# iPhone 11 重复性能探针验收

## 范围

本工作包只覆盖后端 `CubeGenerator` 的重复测量接口和取消观察边界，不涉及任何 UI。目标是为实体 iPhone 11 的热稳态、离散度、取消延迟和内存预算建立可复现入口；本轮没有把设备不可用时的结果替换成其他设备。

## 实现

- 新增 `DevicePerformanceRepeatedMeasurement` 和 `DevicePerformanceRepeatedProbeResult`，schema 为 `native.device-performance-repeat.v1`。
- `DevicePerformanceProbe.runRepeated` 支持 `warmups`、`repetitions` 和同步 `shouldCancel`；每次预热和计时生成前检查取消，统计逐次 Double 秒数、最小值、中位数、最大值，并保存最终生成的 bit-pattern 校验和。
- 保留既有 `native.device-performance.v1` 与 `lutcalc-device-performance.json`。iOS 新环境变量 `LUTCALC_DEVICE_PERFORMANCE_REPEAT=1` 写入 `lutcalc-device-performance-repeat.json`。

## 契约先行

先把 3 项新契约写入 `DevicePerformanceProbeContractsTests.swift`，随后运行旧实现，确认编译失败，退出码为 `1`。失败日志：

`docs/native-validation/artifacts/2026-10-04-device-performance-repeat/swift-release-targeted.log`（先行失败另存于本轮 shell 输出；缺少 `runRepeated` 和 `.cancelled`）。

实现后运行：

```text
swift test --package-path Native/Packages/LUTKit --filter DevicePerformanceProbeContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter DevicePerformanceProbeContractsTests
```

两次均退出 `0`，6 项通过，包含 schema／节点／校验和、JSON 往返、非法重复数／预热数和取消前不执行生成。

## 完整回归与构建

```text
swift test --package-path Native/Packages/LUTKit -c release
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -sdk macosx -destination generic/platform=macOS -derivedDataPath /tmp/lutcalc-macos-performance-repeat-20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/lutcalc-iphone11-performance-repeat-20261004 DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates build
```

- Swift Release 退出 `0`；LUTSharedUI 161、LUTProject 61、LUTPreview 91、LUTJobs 67、LUTFormats 56（其中旧 `.labin` 与 NCP 外部夹具各跳过 1 项）、LUTCore 183、LUTCatalog 24、LUTAnalysis 32，0 失败。
- macOS generic Release 退出 `0`。
- iOS generic Release 签名构建退出 `0`，签名身份为本机 Apple Development，产物为 `/tmp/lutcalc-iphone11-performance-repeat-20261004/Build/Products/Release-iphoneos/LUTCalcIOS.app`。
- 完整日志和退出码位于 `docs/native-validation/artifacts/2026-10-04-device-performance-repeat/`。

## 实体 iPhone 11 尝试

目标设备固定为：`00008030-001015101ABA802E`，型号 `iPhone 11 (iPhone12,1)`。安装命令：

```text
xcrun devicectl device install app --device 00008030-001015101ABA802E /tmp/lutcalc-iphone11-performance-repeat-20261004/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

设备在安装前的 `devicectl list devices` 曾显示 `available (paired) / physical`，但安装返回 CoreDevice `error 4016`：

```text
The device is not able to fulfill the requested usage assertion requirements.
RequestedDeviceStates = powerAssertionTaken, coreDeviceServicesLoaded,
remoteServiceDiscoveryTrustedConnectivityAvailable
```

随后 `devicectl device info details` 显示 `Device State: unavailable`、`tunnelState: unavailable`、`ddiServicesAvailable: false`。安装退出码为 `1`，没有启动探针，没有生成新的真机重复 JSON；没有使用 iPhone Air、镜像或模拟器替代该证据。对应文件：

- `iphone11-install.exit`、`iphone11-install.stdout`、`iphone11-install.json`
- `iphone11-signed-build.exit`（直接指定 iPhone 11 的 xcodebuild 也因当时 destination 不可用退出 `70`）
- `iphone-generic-signed-build.exit`、`iphone-generic-signed-build.log`

## 未覆盖范围

- 尚无实体 iPhone 11 的重复／热稳态样本、内存峰值、取消延迟、批量／图像／写出预算。
- 本地契约和 generic 构建不等于后台恢复、File Provider、iCloud 或真机 UI 验收。
- 完整 ICC、HDR/EDR/OOTF、LUTAnalyst 任意 3D 反求、全部旧相机模型、目标调色软件往返、签名发布和 `full-scope-acceptance.json` 仍未完成。

## 2026-10-04 后续实体 iPhone 11 重试

设备随后恢复为 `available (paired)`，`device info details` 报告 `Device State: connected`、Developer Mode 已启用。固定 UDID `00008030-001015101ABA802E` 上的重新配对和 Release App 安装均退出码 0；没有使用其他设备。

启动命令通过 `devicectl device process launch` 注入 `LUTCALC_DEVICE_PERFORMANCE_REPEAT=1`，进程 PID 为 585。随后从 `org.lutcalc.native.dev.ios` 的 appDataContainer 取回 `Documents/lutcalc-device-performance-repeat.json`，并用 `devicectl device process terminate --pid 585 --kill` 结束进程。

取回文件的 SHA-256 为 `5c9315e196f48c24687c3b350a9a101afe5f65338ff964fd1a0f1fb1917ba94c`。JSON schema 为 `native.device-performance-repeat.v1`，`warmups=1`、`repetitions=5`，17/33/65 网格分别为 4,913/35,937/274,625 节点，每个网格有 5 个有限 Double 秒数。独立 Python 核对确认节点数、重复数、最小／中位／最大统计和有限性一致：

| 网格 | 最小秒数 | 中位秒数 | 最大秒数 | bit-pattern checksum |
| ---: | ---: | ---: | ---: | ---: |
| 17 | 0.001903 | 0.002138375 | 0.041807125 | 14379552350607772001 |
| 33 | 0.0140425 | 0.016970417 | 0.034875625 | 1336097751165010835 |
| 65 | 0.171777125 | 0.192449417 | 0.805787042 | 15217861669287451768 |

实际命令、安装、启动、取回、终止日志和 JSON 位于 `artifacts/2026-10-04-device-performance-repeat/`，文件名带 `iphone11-retry` 或 `iphone11-repeat`。本结果只证明当前探针在一次实体 iPhone 11 会话中的 5 次重复样本；热稳态、多轮独立会话、内存峰值、取消延迟、批量／图像／写出预算和发布性能门槛仍未完成。

## 2026-10-04 三次独立会话补充

在用户要求停止追加真机性能工作之前，已完成三次独立启动、取回和终止，设备仍固定为实体 iPhone 11 `00008030-001015101ABA802E`。三次 launch、copy 和 terminate 均退出码 0；没有使用 iPhone Air、镜像或模拟器。

三份 JSON 均由独立 Python 核对 schema、`warmups=1`、`repetitions=5`、17/33/65 节点数、有限 Double 样本、最小／中位／最大统计和 SHA-256。逐文件哈希与三会话汇总见 `artifacts/2026-10-04-device-performance-repeat/iphone11-multisession-independent-summary-20261004.log`。

| 网格 | 三次会话中位数 | 三会话中位数的中位数 | 全部 15 个样本均值 | 全部 15 个样本总体标准差 |
| ---: | ---: | ---: | ---: | ---: |
| 17 | 0.00199025 / 0.002065542 / 0.002072833 | 0.002065542 | 0.002232711133333333 | 0.000504514545622868 |
| 33 | 0.029227917 / 0.016341916 / 0.01688675 | 0.01688675 | 0.021010119266666665 | 0.008473378342297885 |
| 65 | 0.122375167 / 0.109782875 / 0.108247875 | 0.109782875 | 0.1161493528 | 0.01650922345534498 |

这组数据仍只是探针重复样本，不构成完整性能预算、内存峰值、后台恢复或发布门槛验收；后续按用户要求跳过追加真机性能工作。

本记录只关闭重复性能 API 与跨平台编译子集，H/FULL 和 Goal 保持 active。
