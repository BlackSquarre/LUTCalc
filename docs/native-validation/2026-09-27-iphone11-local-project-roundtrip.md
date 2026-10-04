# 2026-09-27 iPhone 11 本地项目关闭重开验收

## 范围与夹具

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）、Xcode 27.0、Swift 6.4、`xcrun devicectl` 与 XCTest。没有使用 iPhone Air、iPhone 镜像或模拟器作为真机证据。

从设备 App 数据容器只读取回已有的 `2026-09-24-mac-roundtrip.lutcalc`，其 v1 `manifest.json` 的 SHA-256 为 `5c0093ab57b4b3a64b5ef75dee1306fad0328205bdd8ff826a863db5785d53b0`，曝光为 `0.5`。先用 `devicectl device process launch --payload-url` 打开它，XCTest 在原生文稿界面确认文件名和曝光值。随后在 `/tmp` 复制该夹具、换用独立 UUID `DC78E22A-1057-4DE3-A5F0-5F4983D3EFEF`，得到 `LUTCalc-device-roundtrip-20260927.lutcalc`。复制品初始清单 SHA-256 为 `ae2797d885a85ddf59e53b40790c1d0d49cf397ab95aa60f1914f45d101207c4`；原设备项目未修改。夹具中的 JSON 调整只发生在研发验证副本，不属于 App 文件解析或项目存储实现。

## 实际步骤与结果

1. `xcrun devicectl device copy to --device 00008030-001015101ABA802E --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source /tmp/LUTCalc-device-roundtrip-20260927.lutcalc --destination Documents/LUTCalc-device-roundtrip-20260927.lutcalc`：退出码 0，设备返回 App 数据容器中的项目包路径。
2. `xcrun devicectl device process launch --device 00008030-001015101ABA802E --terminate-existing --payload-url 'file:///private/var/mobile/Containers/Data/Application/2D08CC0E-D1ED-4D88-8CA1-8BF271879AC3/Documents/LUTCalc-device-roundtrip-20260927.lutcalc' org.lutcalc.native.dev.ios`：退出码 0。
3. 使用 `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testEditExistingProjectPayloadURLDiagnosticOnDevice test`：退出码 0；临时验收测试在原生界面确认曝光 `0.5`，改为 `2.75`、应用并关闭文稿。结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-21-14-+0800.xcresult`；日志 `/tmp/lutcalc-project-roundtrip-edit.log`，SHA-256 `5174dcb85e8db472d3da50abe057a65d864226d8a16d344f463a1ffb29ea65e9`。
4. `xcrun devicectl device copy from --device 00008030-001015101ABA802E --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source Documents/LUTCalc-device-roundtrip-20260927.lutcalc --destination /tmp/lutcalc-device-roundtrip-after-edit`：退出码 0。回读清单为 schema v2，`exposureStops` 为 `2.75`，项目 UUID 不变；清单 SHA-256 `17554c8661465a206af05933faa07346142a5f545753939a6ae50adc00abf11d`。
5. 再次执行第 2 步的 `--payload-url` 启动，随后以相同 `xcodebuild` 参数运行 `testReopenEditedProjectPayloadURLDiagnosticOnDevice`：均退出码 0。结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-22-33-+0800.xcresult` 报 `Passed`，设备为上述 iPhone 11。UI 层级显示项目名 `LUTCalc-device-roundtrip-20260927.lutcalc`，曝光输入框值 `2.75`。日志 `/tmp/lutcalc-project-roundtrip-reopen.log`，SHA-256 `3799355487812aacd65ad47d0d00c451515bced09c0ae7eb85ac1a02a81da01e`；层级附件 `/tmp/lutcalc-project-roundtrip-reopen-attachments/90419297-C31B-4758-968F-C635CECCDEE7.txt`，SHA-256 `6924219952a2d8f46850f3e0e5039da801687d6041d501e87c89791316432da5`。

两个临时 XCTest 方法依赖设备预置夹具和外部 `--payload-url` 步骤，验收后已从常规测试源码移除，避免日常全量测试误报；结果包保留了当时执行的测试记录。最终常规 UI 测试源码 SHA-256 `ac7f16bfcb5e07692924e2f41e4a278d310ae382119eb340fdcd503322c53259`。本轮只修改文档，没有改 App 数值路径、格式解析或旧测试夹具。

## 结论与未覆盖

这证明实体 iPhone 11 上，App 本地容器中的 `.lutcalc` 能由系统文件 URL 打开、在 SwiftUI 中编辑、关闭后写回、再从同一路径重新打开并保留设置；也观察到 v1 清单在保存时写为 v2。它不证明 iCloud/File Provider 授权失效、外部替换竞争、Files 浏览器手动选择、项目资源包、iPad 多窗口或 macOS Finder 往返。没有为颜色数值准确度增加新证据，也不满足全量发布门槛。
