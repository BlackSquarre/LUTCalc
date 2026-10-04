# 2026-09-27 iPhone 11 独立 Files 本地列表回查验收

## 范围与工具

本轮只使用有线连接的实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）。通过 Xcode 27.0（27A266a）、Swift 6.4、`xcodebuild` 和 XCTest 直接操作系统 Files 应用；没有使用 iPhone Air、iPhone 镜像或模拟器作为真机证据。

## 修改文件与契约

- `Native/Tests/iOSUI/LUTCalcIOSUITests.swift`：在 CUBE 导出、系统保存回调 URL 字节回读后，启动独立 `com.apple.DocumentsApp`，进入 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”位置，并要求 `File View` 内出现本次文件名对应的 `.cube` 文件单元格。
- 系统导出面板的搜索结果与独立 Files 列表分别记录；断言限定为文件单元格，不能匹配搜索框。Files 返回按钮的可访问性点击在这台设备上没有稳定进入位置列表；XCTest 使用按钮所在屏幕位置完成第二次点击，并要求本地位置标识出现后才继续。
- `docs/native-swift-roadmap.md`：更新该项已验证范围及剩余缺口。

## 实际验收

- 命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedCubeAndReadBackOnDevice test`。
- 最终真机测试退出码 0；`xcresulttool` 报 `Passed`，设备 UDID 与型号均为上述 iPhone 11。结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_04-58-06-+0800.xcresult`；日志 `/tmp/lutcalc-files-independent-final-20260927.log`，SHA-256 `4ada6c333bb27d963754cb85c240387730cc4cee724c2da9cc7fd4feef4b1635`。最终测试源码 SHA-256 `ac7f16bfcb5e07692924e2f41e4a278d310ae382119eb340fdcd503322c53259`。
- 最终结果包附件中，独立 Files 位于 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”，`File View` 文件单元格列出本轮 `LUTCalc-device-FA368A03.cube`，约 279 KB。附件 `/tmp/lutcalc-files-independent-final-attachments/2CEB02C4-CC8C-4541-A17E-F096630A9356.txt`，SHA-256 `464b7e37a6003bfe9851f9921701afaef1a02b34895d6808ea576021968efb01`。
- 前一轮通过结果包：`/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_04-55-01-+0800.xcresult`，`xcresulttool` 报 `Passed`，设备为实体 iPhone 11。日志 `/tmp/lutcalc-files-independent3-20260927.log` 的 SHA-256 为 `d47dea22a5fb19be34cd70dd098bfbe93f9f40bf6748d6972c82cc4699549949`。
- 该结果包附件中，Files 当前目录标识为 `DOC.browsingRoot Source: com.apple.FileProvider.LocalStorage, Title: 我的iPhone`；`File View` 文件单元格明确列出本次的 `LUTCalc-device-27D8A012.cube`，显示约 279 KB。层级附件为 `/tmp/lutcalc-files-independent3-attachments/6615BC90-75CE-4A3B-90BF-D666DD55E1ED.txt`，SHA-256 `c17d6fcb098712b434527861e2fa34293ba91ebdd5e7ec8e46169bd39eabda41`。
- 同一测试还要求应用显示 `.fileExporter` 回调 URL 的字节回读一致状态。系统导出面板再次搜索仍可能显示“未找到”，但独立 Files 本地列表证明该文件已出现；两种观测不能混为一项。
- 本轮只修改 UI 契约与文档，未改数值核或夹具；此前完整 Swift Release、macOS/iOS generic Release 构建和 App 静态审计结果见[本地 Files 导出回读验收](2026-09-27-iphone11-files-local-readback.md)，本轮不重复冒称这些命令已重新运行。

## 未覆盖

尚未从 Files 再次导入 CUBE 或 `.lutcalc` 项目包；File Provider 权限失效与替换竞争、其他格式、iPad 多窗口、macOS Finder 往返、目标软件导入、完整旧功能和发布验收仍缺证据。`full-scope-acceptance.json` 不能因这项通过而创建为全量通过。

## `.lutcalc` 重开调查

同一设备继续尝试了创建文稿、将曝光改为 `2.75`、关闭、从系统文稿浏览器查找同名 `.lutcalc` 并重开。四次探索性测试均未完成内容核对：第一次未定位到搜索按钮；第二次找到了项目包并打开系统信息页，信息页明确显示“种类：LUTCalc 项目”“始终以此方式打开：LUTCalcIOS”和独立的“打开”按钮，但当次未点击该按钮；第三次搜索框未出现；第四次因系统浏览器状态残留，搜索未返回本次新文稿。失败结果包依次为 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-04-12-+0800.xcresult`、`/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-05-59-+0800.xcresult`、`/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-09-49-+0800.xcresult` 和 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-11-04-+0800.xcresult`；最终失败日志 `/tmp/lutcalc-project-reopen4.log`。探索性测试已从源码移除，避免继续在用户 iCloud 中生成文稿；最终 UI 测试源码哈希与上方通过的 CUBE 回查版本一致。项目包关闭重开仍为未验收，不据此判断项目读取实现有缺陷或已通过。
