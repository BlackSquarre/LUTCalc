# 2026-09-27 iPhone 11 3DL 本地 Files 往返验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），通过 Xcode 27、`xcodebuild` 和 XCTest 验证 3DL 的原生生成、系统保存回调字节回读以及独立 Files 本地列表发现。没有使用 iPhone Air、手机镜像或模拟器作为真机证据。

测试选择合法的 `dji.dlog2-to-dlog2-identity.v1` 预设，使 3DL 的单位输入域和 0…1 输出约束可满足；没有修改 Double 生成路径、网格、量化或插值规则。

## 先行契约

- `ThreeDLExportContractsTests` 3 项通过，覆盖 Flame 轴顺序与 half-up 码值、扩展域/越界样本拒绝、取消写出和拒绝覆盖时保留原目标。
- `git diff --check` 通过。
- iOS UI 测试构建 `build-for-testing` 退出码 `0`；构建输出中的 Swift 并发隔离提示为既有 XCTest 调用方式警告，没有编译错误。

## 实体设备命令与结果

命令：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalc3DLDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedThreeDLAndReadBackOnDevice test
```

- 退出码 `0`；日志 `/tmp/lutcalc-iphone11-3dl-files-roundtrip.log`，SHA-256 `0b094941d3082a717b13b58c4f3c3546988150677a7bb04226c17368947023ad`。
- 结果包：`/tmp/LUTCalc3DLDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_16-11-31-+0800.xcresult`。
- `xcresulttool` 摘要确认设备型号 `iPhone 11`、UDID 正确、iOS `26.5`，测试 `testSaveGeneratedThreeDLAndReadBackOnDevice()` 为 `Passed`；摘要 JSON `/tmp/lutcalc-iphone11-3dl-summary.json`，SHA-256 `6acb9ccdef649305c00b95fb86b2d857810cc5bf5938902f17861148f6e609e7`。
- XCTest 在 App 内确认系统保存回调 URL 的 3DL 字节回读成功，状态文案为 `文件已保存并回读核对：<随机名>.3dl`。
- 独立 `com.apple.DocumentsApp` 进入 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”，`File View` 实际列出本次文件，例如 `LUTCalc-3dl-981DF241.3dl`，约 74 KB。结果包附件导出目录：`/tmp/lutcalc-3dl-xcresult-export-20260927`；Files 层级附件 SHA-256 `cbf3ba5d2847a40868533b81a35de2cf5e2cb4e4da1767c2bcd772da2d2669c7`。

## 未覆盖范围

本轮未从 Files 再次导入 3DL、未在 Resolve/Assimilate 或其他目标调色软件中导入验证，也未覆盖 iCloud/File Provider 授权失效、外部替换竞争、iPad 多窗口、macOS Finder 往返和完整发布清单。因此只增加 3DL 本地保存/回读/独立列表证据，不勾选 FULL-06 全格式目标软件往返或 Goal 完成。
