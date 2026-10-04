# 2026-09-27 iPhone 11 本地 Files 导出回读验收

## 范围与设备

仅使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）、`xcodebuild` 和系统 Files 保存面板。本次未使用 iPhone Air、镜像或模拟器作为真机证据。工具链为 Xcode 27.0、Swift 6.4。

## 修改文件

- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：生成文件经系统 `.fileExporter` 返回 URL 后，在 security scope 有效期间回读，逐字节比较生成文稿快照；UI 分别报告已回读一致、回读失败或字节不一致。
- `Native/Tests/iOSUI/LUTCalcIOSUITests.swift`：新增实体设备契约，创建文稿、生成 CUBE、进入系统“我的iPhone”位置、更改文件名、提交保存，并要求 App 出示字节回读一致状态。随后再次进入 Files 面板尝试文件列表检索，保存层级诊断附件。

本轮最终 UI 测试源码 SHA-256 `254021b1b9e753d5f0c31fafc6658fd44fe49ea049009a610b507730d25fcaf4`；视图源码 SHA-256 `8d4e11fa2ccb24bf66367531cae2ea9bce2c13c7629f1ccf1eb7f1fc06ef2319`。这两项是源码哈希，不是发布包哈希。

## 实际结果

- 初次尝试按“我的 iPhone”按钮查找失败。XCTest 层级证明正确类型为 `Cell`，标识为 `DOC.sidebar.item.我的iPhone`、显示为“我的iPhone”。这修正了之前未能到达本地位置的原因。
- 一次 UI 测试曾返回通过，但附件显示 Files 搜索框本身匹配了文件名，属于假阳性；已将查找限定为 `File View` 内的文件单元格，未把该次结果记为落盘证据。
- 最终命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedCubeAndReadBackOnDevice test`。退出码 0；`xcresult` 中设备 UDID 正确，测试结果 `Passed`。日志 `/tmp/lutcalc-iphone11-files-readback-final-20260927.log`，SHA-256 `f1ec63d6ab911150150c243641c9c9ca715fbb52d0498524afb6ec06916d99fc`；结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_04-37-08-+0800.xcresult`。
- 最终结果包附件中，App 明确显示“文件已保存并回读核对：LUTCalc-device-EB678296.cube”。这来自 `.fileExporter` 成功回调返回的 URL，`Data(contentsOf:)` 与生成文稿的字节数组逐字节相等。该结果证明应用通过该 URL 实际读到了提交文件的原字节。
- 同一结果包附件的 Files 保存面板搜索仍显示“未找到‘LUTCalc-device-EB678296’的相关结果”；因此系统 Files 列表独立发现、从 Files 再次打开和目标软件导入尚未通过。回调 URL 的回读与 Files 搜索是两项分开的证据。
- 完整 `swift test -c release --package-path Native/Packages/LUTKit` 退出码 0，日志 `/tmp/lutcalc-files-readback-swift-tests.log`，SHA-256 `1c4332b31b60fd71f5f220a469e79650bbf1edfba31b86f9160f0b6b7c38262d`。
- macOS 与 iOS generic Release 未签名构建分别退出码 0，日志 `/tmp/lutcalc-files-readback-mac-build2.log` 与 `/tmp/lutcalc-files-readback-ios-build.log`（quiet 模式无输出，SHA-256 均为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）。一次并行 macOS 构建因共用 DerivedData 的 `build.db` 锁退出 65，随后使用独立 `/tmp/LUTCalcFilesMacRelease` 目录重新构建通过；没有清理或修改用户文件。
- `python3 tools/native-validation/audit-native-bundles.py` 对上述 macOS/iOS 两个 Release App 包审计退出码 0；没有发现所列 LUT/脚本资源或 WebKit/JavaScriptCore 直接链接。日志 `/tmp/lutcalc-files-readback-bundle-audit.log`，SHA-256 `6fe75fccbb488ecac6fb3dbbd0c7ddfe878b9f6f41b69972614929b847be864a`。该静态审计不替代等价采样表与公式来源的人工复核。
- `python3 tools/native-validation/check-release-evidence.py` 仍退出 2，原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

## 未覆盖

本次没有证明 Files 列表可再次找到该文件、从 Files 重开 `.lutcalc` 项目包、File Provider 失效/替换竞争、iPad 多窗口、macOS Finder 往返、目标软件导入、完整旧功能与发布签名。不能将保存回调及字节回读扩大为完整 Files/发布验收。
