# 2026-09-27 iPhone 11 VLT 本地 Files 往返验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），没有使用 iPhone Air、镜像或模拟器作为真机证据。

## 实际命令与结果

- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedVLTIdentityPresetAndReadBackOnDevice test`
- 退出码 `0`；结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_06-20-04-+0800.xcresult` 报告 1 项通过、0 项失败。
- 日志 `/tmp/lutcalc-vlt-files-local-20260927.log`，SHA-256 `b9ad147e9a0f65ca5d9191ee943158de43268d4b950890e4832ea5718533a2f2`。

## 验收内容

- 在 SwiftUI 项目界面选择注册表预设 `dji.dlog2-to-dlog2-identity.v1`，确认 VLT 的单位域、17³、0…1 约束由实际项目设置满足。
- 选择 `VLT Varicam 17³`，生成成功状态出现。
- 系统保存面板写入“我的 iPhone”唯一 `.vlt` 文件；App 收到回调后显示“文件已保存并回读核对”，执行现有字节级比较。
- 独立 Files App 进入 `com.apple.FileProvider.LocalStorage`，发现本次 `.vlt` 文件单元格。

## 未覆盖

本轮只证明本地 Files 位置。iCloud/File Provider 授权失效与替换竞争、Panasonic/第三方软件导入、项目资源重开、iPad 多窗口及 macOS Finder 往返仍未完成。

