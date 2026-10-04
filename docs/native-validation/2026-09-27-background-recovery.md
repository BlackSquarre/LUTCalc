# 2026-09-27 后台恢复阶段验收

## 范围

本阶段为导出任务补齐 SwiftUI `scenePhase` 生命周期边界：进入后台时取消尚未完成的导出，不能把未完成任务写成成功；回到前台后允许重新创建导出请求；已经完成的 `lastExport` 保持可用。本阶段只验证原生 Swift 任务生命周期和可执行构建，不把本地契约测试解释为 iCloud/File Provider 或系统后台终止证据。

## 契约与实现

- `ProjectExportSession.suspendForBackground()` 统一取消当前运行中的导出。
- `ProjectDocumentView` 在 `.background` 调用挂起逻辑，在 `.active` 调用 `reopen()`。
- 新增 `ProjectExportLifecycleContractsTests.testBackgroundSuspensionCancelsInFlightExportAndAllowsRecovery`，使用延迟导出服务确认：后台后状态为 `.cancelled`、没有伪造 `lastExport`，恢复后再次导出进入 `.succeeded`。
- iOS UI 新增 `testBackgroundCancelsExportAndRecoversOnDevice`，目标设备固定为实体 iPhone 11（UDID `00008030-001015101ABA802E`）。

## 实际命令与结果

- 工具链：Xcode `27.0`（`27A266a`），Apple Swift `6.4`。
- `swift test --package-path Native/Packages/LUTKit -c release --filter ProjectExportLifecycleContractsTests`
  - 4 项通过、0 失败。
  - 日志：`/tmp/lutcalc-background-recovery-release.log`。
  - SHA-256：`e26732d3f7d075988b4f0be984586cbf279c6f081c1e0bc2b5e5e0824fb19afd`。
- `swift test --package-path Native/Packages/LUTKit -c release`
  - 全包 Release 测试退出码 `0`，所有测试套件通过。
  - 日志：`/tmp/lutcalc-background-full-swift-release.log`。
  - SHA-256：`a23e9eca59bf718dcb9f992d107fcbc7dafe011a5087f9c8731c6ab07f7fdb2d`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build`
  - 退出码 `0`。
  - 日志：`/tmp/lutcalc-background-mac-release.log`，SHA-256 `612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - 退出码 `0`。
  - 日志：`/tmp/lutcalc-background-sim-release.log`，为空日志，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
  - 退出码 `0`。
  - 日志：`/tmp/lutcalc-background-ios-release.log`，为空日志，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `git diff --check` 通过。上述修改未触及 Double 采样、网格、量化、插值或误差阈值，数值路径没有新增误差。

## 实体 iPhone 11 UI 阻塞

使用 `xcodebuild` 直接运行新增测试，设备为实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），两次均在 UI runner 初始化阶段退出，测试方法没有进入：

- `/tmp/lutcalc-iphone11-background-recovery.log`：退出码 `65`，SHA-256 `6bcd52936b0800903c54535b3824a2def93961d11dcdf821f93e7ac850598822`。
- `/tmp/lutcalc-iphone11-background-recovery-retry.log`：退出码 `65`，SHA-256 `5c84592d8cf55159a96864436f3f8951170fb225e7544285a4e3cc7129e53b7c`。
- 两次日志都指向 UI runner `Timed out while enabling automation mode`；没有断言失败、没有进入后台恢复测试体，因此不计为真机通过证据。

## 未覆盖范围

本阶段未取得真实设备后台挂起后的进程终止与重新启动证据，也未覆盖 iCloud/File Provider 授权失效、文稿替换竞争、磁盘故障、iPad 多窗口/旋转/无障碍和完整发布清单。`docs/native-validation/full-scope-acceptance.json` 仍不存在，Goal 继续保持 active。

## 2026-09-27 交接后复验与失败记录

针对首次真机 UI runner 超时，本轮先增加了两个 Swift 契约：取消后忽略取消的服务晚返回不得改回成功；空闲挂起后重新打开仍可创建请求。`ProjectExportLifecycleContractsTests` 定向运行 6 项全部通过，日志 `/tmp/lutkit-export-contracts-20260927b.log`，SHA-256 `218687c92217b487074e14d14b96ae41278f7649bba0a12d1ae1890ee2dbc865`。

实现保留 SwiftUI `scenePhase` 与 UIKit `onReceive` 前后台观察，并将 iOS `ProjectDocumentView.onDisappear` 作为保守后台取消边界；生成路径、Double、网格、位宽和阈值没有改变。iOS generic Debug 构建通过；构建日志为空，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）实际进入测试方法后仍未通过：

- 重跑 2：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry2-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-22-27-+0800.xcresult`，失败为后台后未显示“生成已取消”，日志 SHA-256 `eec9f71b24ad112e8e09bf3d6504e8325a8fdd3fa303a070b9ffaa4b752e7cca`。
- 重跑 3：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry3-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-26-47-+0800.xcresult`，同一断言失败，日志 SHA-256 `2ba70f560c7b0cd8d432a7f4b5a6419e92f990358d7954c5841a0e95182b2af7`。
- 重跑 4：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry4-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-29-15-+0800.xcresult`。新增滚动后，层级显示首次导出已成功且有 4,913 个节点，说明后台取消边界仍未生效；日志 SHA-256 `a3caa89c1637b26ab65e9e5eab16527ddfe5a3c079ec331512e8723e41d7738e`。
- 重跑 5：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry5-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-33-20-+0800.xcresult`，同一断言失败，日志 SHA-256 `a24b1ed9b729b6a71c153c809fad84a26198d70725b986fc4b8aee3a1de78053`。
- 重跑 6：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry6-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-36-19-+0800.xcresult`，同一断言失败，日志 SHA-256 `ae325e8c1a246c88ccf11391aaac139f20ae645a68029941d96162ec25fc92de`。
- 重跑 7（移除会话级通知注册后的最终代码）：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry7-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-44-05-+0800.xcresult`，仍为后台后未显示“生成已取消”，日志 SHA-256 `2b006884c9128eeafac2564706cde4bcdab60d39b7a60f1980a9d6ca7d42bcf6`。
- 重跑 8（测试延长后台停留到 3 秒，Debug 慢导出延长到 15 秒）：退出码 `65`，结果包 `/tmp/LUTCalcDeviceUITestDD-Retry8-20260927/Logs/Test/Test-LUTCalcIOS-2026.09.27_18-47-22-+0800.xcresult`，仍为后台后未显示“生成已取消”，日志 SHA-256 `6c0633663dca40cfbbee8851f95b85194bf02b19677b05a528dab6f95d537d31`。

同一实体 iPhone 11 上，显式点击取消的 `testCancelLUTGenerationOnDevice` 仍通过 1 项；结果包位于 `/tmp/LUTCalcDeviceUITestCancel-20260927/Logs/Test/`。因此当前证据只支持显式取消，不支持后台恢复取消；本阶段不能勾选真机后台恢复，也不能声称 H08/FLOW-02 已完成。每次结果包的 devicectl 诊断收集另有系统错误，但不是上述主断言原因。

随后移除了临时的会话级通知注册，避免每个 `ProjectExportSession` 累积无法回收的观察者；当前生命周期入口只保留 SwiftUI `scenePhase`、视图级 UIKit `onReceive` 和 iOS `onDisappear` 取消边界。全包 Release Swift 回归重新通过 302 项，日志 `/tmp/lutcalc-full-swift-release-after-background-20260927.log`，SHA-256 `c34f3a792584321ddabb5876bb4e81068e00a98d8d9f6a084470b28020348a44`。

在重跑 8 后又增加了 `UIApplication.willResignActiveNotification` 这一更早的取消边界；iOS generic Debug 构建通过，日志为空，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。尚未用该最后改动重新取得真机正证据，因此仍不计为通过。
