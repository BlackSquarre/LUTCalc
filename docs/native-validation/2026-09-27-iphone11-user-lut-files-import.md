# 2026-09-27 iPhone 11 用户 CUBE 导入与项目资源重开验收

## 范围与前置文件

仅使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）、Xcode 27.0、Swift 6.4、`xcodebuild`、XCTest 和 `xcrun devicectl`。项目为[本地项目关闭重开验收](2026-09-27-iphone11-local-project-roundtrip.md)中的独立设备夹具 `LUTCalc-device-roundtrip-20260927.lutcalc`，初始 schema v2、曝光 `2.75`、无资产。用户选择的源文件是此前在系统“我的iPhone”位置保存并由独立 Files 列表确认的 `LUTCalc-device-FA368A03.cube`。没有把它打包进 App 或用作内置颜色转换。

## 实际步骤与结果

1. 使用 `xcrun devicectl device process launch --device 00008030-001015101ABA802E --terminate-existing --payload-url 'file:///private/var/mobile/Containers/Data/Application/2D08CC0E-D1ED-4D88-8CA1-8BF271879AC3/Documents/LUTCalc-device-roundtrip-20260927.lutcalc' org.lutcalc.native.dev.ios` 打开独立项目，退出码 0。
2. 用 `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testUserLUTImportPickerDiagnosticOnDevice test` 运行临时真机契约，退出码 0。系统导入面板位于 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”；`File View` 文件单元格列出 `LUTCalc-device-FA368A03.cube`，测试点选该单元格。随后 SwiftUI 显示“项目资源”及“格式与尺寸、cube，3D，17”，测试关闭文稿。结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-27-44-+0800.xcresult` 报 `Passed`；日志 `/tmp/lutcalc-userlut-import-device1.log`，SHA-256 `5c472c8df0fdfa6ebf9e84ffc7911228e72e51b52e3e0b975251b7d31c5b7484`。
3. 用 `xcrun devicectl device copy from --device 00008030-001015101ABA802E --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source Documents/LUTCalc-device-roundtrip-20260927.lutcalc --destination /tmp/lutcalc-device-after-userlut-import` 只读回设备项目包，退出码 0。清单仍为 schema v2、曝光 `2.75`、原项目 UUID；`assetRoles` 将 `Resources/user-7ea10aad-b4c2-4d39-8a45-1208cc3053a6.cube` 标为 `userLUT`。资源为 279,334 字节，实际 SHA-256 `251bbd4b8c6eb3337f58547bb2dd9be7245d16dc50f50f6542e962c3f4e9fb5b`，与 `assetHashes` 相等。回读清单 SHA-256 `ea818e13f8670543ebefc8def561c4b450a68762f6ed6c391de6cfb2b650178e`。
4. 再次用第 1 步的 `--payload-url` 启动，并以相同 `xcodebuild` 参数只运行 `testStoredUserLUTReopenDiagnosticOnDevice`，均退出码 0。结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-29-37-+0800.xcresult` 报 `Passed`，设备为上述 iPhone 11；原生界面重新显示同名项目资源和文件。日志 `/tmp/lutcalc-userlut-reopen-device.log`，SHA-256 `340c51346248832b83d0ac6be1a1d8f86a2d54f048ed475e42cb5e2dc97676eb`；层级附件 `/tmp/lutcalc-userlut-reopen-attachments/436C34A3-18EA-43CB-B875-75C07598DA11.txt`，SHA-256 `6cca2bdaf7a3ea6c6b8870a03604e852326755868c0eccc3433a1a379dcf400e`。

导入与重开的两个临时 XCTest 方法依赖上述设备文件和外部 URL 启动，验收后已从常规测试源码移除，避免全量测试误报。最终常规 UI 测试源码 SHA-256 `ac7f16bfcb5e07692924e2f41e4a278d310ae382119eb340fdcd503322c53259`。本轮没有修改 App 实现、数值算法或冻结夹具。

## 未覆盖

此项证明用户主动选择 CUBE、Swift 解析为 17³ 三维 LUT、原字节存入项目包并在本地项目重开后仍显示。它不证明该三维 LUT 可逆或已进入生成计划；也不证明 iCloud/File Provider 授权失效、外部替换竞争、其他 LUT 格式真机导入、目标软件往返、iPad 多窗口或完整发布验收。内置算法仍须独立审计，不得以用户导入文件代替内置公式。
