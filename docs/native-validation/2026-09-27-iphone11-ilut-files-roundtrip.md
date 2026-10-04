# 2026-09-27 iPhone 11 ILUT 本地 Files 往返验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），通过 Xcode 27、`xcodebuild` 和 XCTest 验证 ILUT 的原生 14-bit 1D 生成、系统保存回调字节回读和独立 Files 本地列表发现。没有使用 iPhone Air、手机镜像或模拟器作为真机证据。

测试选择合法的 `dji.dlog2-to-dlog2-identity.v1` 预设，使 ILUT 的单位输入域、同色域和可表示输出约束可满足；没有修改 Double 生成路径、16384 点采样、量化或插值规则。

## 先行契约与构建

- `ILUTExportContractsTests` 既有格式和 sink 契约保持通过，覆盖固定 14-bit 行数、单位域/符号零拒绝、不可表示计划拒绝和取消/覆盖边界。
- `xcodebuild ... build-for-testing` 退出码 `0`；日志 `/tmp/lutcalc-ilut-build-for-testing.log`，SHA-256 `b18e8660b80f0e23f7eb2ae92f313c117373a41cc67a12054ae8bfc57ef5d916`。
- `git diff --check` 通过。

## 实体设备命令与结果

命令：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcILUTDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedILUTAndReadBackOnDevice test
```

- 退出码 `0`；日志 `/tmp/lutcalc-iphone11-ilut-files-roundtrip.log`，SHA-256 `8e32abc94c06d8eee0efea054b151a32b857bb5e54a71b73ace48db70421282`。
- 结果包：`/tmp/LUTCalcILUTDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_16-15-34-+0800.xcresult`。
- `xcresulttool` 摘要确认设备型号 `iPhone 11`、UDID 正确、iOS `26.5`，测试 `testSaveGeneratedILUTAndReadBackOnDevice()` 为 `Passed`；摘要 JSON `/tmp/lutcalc-iphone11-ilut-summary.json`，SHA-256 `8360b82a22b993ad1aeb059a670adb32b826cca59d62b754fbcd5543f89762e9`。
- XCTest 在 App 内确认系统保存回调 URL 的 ILUT 字节回读成功，状态文案为 `文件已保存并回读核对：<随机名>.ilut`。
- 独立 `com.apple.DocumentsApp` 进入 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”，`File View` 实际列出本次文件，例如 `LUTCalc-ilut-6ADE5C05.ilut`，约 294 KB。结果包附件导出目录：`/tmp/lutcalc-ilut-xcresult-export-20260927`；Files 层级附件 SHA-256 `e4a3dd94283b8287c670ad361dc6f8fea8a71779eecff79ac9f25433636b0568`。

## 未覆盖范围

本轮未从 Files 再次导入 ILUT，未在 Resolve 中导入验证，也未覆盖 OLUT/Assimilate LUT 真机保存、iCloud/File Provider 授权失效、外部替换竞争、iPad 多窗口、macOS Finder 往返和完整发布清单。因此只增加 ILUT 本地保存/回读/独立列表证据，不勾选 FULL-06 全格式目标软件往返或 Goal 完成。
