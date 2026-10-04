# 2026-09-27 iPhone 11 OLUT 本地 Files 往返验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），通过 Xcode 27、`xcodebuild` 和 XCTest 验证 OLUT 的原生 12-bit 1D 生成、系统保存回调字节回读和独立 Files 本地列表发现。没有使用 iPhone Air、手机镜像或模拟器作为真机证据。

测试选择合法的 `dji.dlog2-to-dlog2-identity.v1` 预设，使 OLUT 的单位输入域、同色域和可表示输出约束可满足；没有修改 Double 生成路径、4096 点采样、量化或插值规则。

## 先行契约与构建

- `OLUTExportContractsTests` 既有格式和 sink 契约保持通过，覆盖固定 12-bit 六列行、单位域/符号零拒绝、不可表示计划拒绝和取消/覆盖边界。
- `xcodebuild ... build-for-testing` 退出码 `0`；日志 `/tmp/lutcalc-olut-build-for-testing.log`，SHA-256 `4c89944455d0c3e0686a28d9c31bceee3f6a59c4009eb39f13ac774b738ccea2`。
- `git diff --check` 通过。

## 实体设备命令与结果

命令：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcOLUTDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedOLUTAndReadBackOnDevice test
```

- 退出码 `0`；日志 `/tmp/lutcalc-iphone11-olut-files-roundtrip.log`，SHA-256 `cc874bea196d7d2be5ba065772f1ca493d922def652dd9bf29763d8f4f2f188a`。
- 结果包：`/tmp/LUTCalcOLUTDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_16-20-07-+0800.xcresult`。
- `xcresulttool` 摘要确认设备型号 `iPhone 11`、UDID 正确、iOS `26.5`，测试 `testSaveGeneratedOLUTAndReadBackOnDevice()` 为 `Passed`；摘要 JSON `/tmp/lutcalc-iphone11-olut-summary.json`，SHA-256 `96e4116a3204868f85197aedf5d15cd4327643d2c6f53c8def4d91dd3c0793d8`。
- XCTest 在 App 内确认系统保存回调 URL 的 OLUT 字节回读成功，状态文案为 `文件已保存并回读核对：<随机名>.olut`。
- 独立 `com.apple.DocumentsApp` 进入 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”，`File View` 实际列出本次文件，例如 `LUTCalc-olut-92740575.olut`，约 116 KB。结果包附件导出目录：`/tmp/lutcalc-olut-xcresult-export-20260927`；Files 层级附件 SHA-256 `bfff5dbd2dd0bb9fad0f5f8c545a0ab37fda939ea3bec54ac2aa55b46c22b205`。

## 未覆盖范围

本轮未从 Files 再次导入 OLUT，未在 Resolve 中导入验证，也未覆盖 Assimilate LUT 真机保存、iCloud/File Provider 授权失效、外部替换竞争、iPad 多窗口、macOS Finder 往返和完整发布清单。因此只增加 OLUT 本地保存/回读/独立列表证据，不勾选 FULL-06 全格式目标软件往返或 Goal 完成。
