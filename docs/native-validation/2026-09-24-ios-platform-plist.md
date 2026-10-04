# iOS/iPadOS 启动与方向声明阶段验收

日期：2026-09-24。状态：**iOS/iPadOS 双设备方向和系统启动屏声明已进入实际 Release 构建；横竖屏真机操作与最终视觉设计仍未验收。** 本项只修复首次 iPhone 开发签名构建暴露的两条平台配置警告，界面仍是功能草稿。

依据 Apple 的 [`UISupportedInterfaceOrientations` 说明](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/iPhoneOSKeys.html)及[设备特定键示例](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html)，iPhone 声明直立和左右横屏，iPad 另外声明倒置直立；[iPad 多任务说明](https://developer.apple.com/documentation/uikit/uiviewcontroller/supportedinterfaceorientations)要求支持全部方向。[`UILaunchScreen` 说明](https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen)允许用字典提供系统启动屏配置。未加入品牌图像或最终视觉样式。

先扩展 `verify-native-document-types.py` 的平台契约，要求上述方向集合和启动屏字典；首次运行退出码 1，明确报 `iPhone 横竖屏声明不完整`。随后修改 `Native/Apps/iOS/Info.plist`，静态验证与 `plutil -lint` 退出码均为 0。两个实际构建的 `Release-iphonesimulator/LUTCalcIOS.app/Info.plist` 与 `Release-iphoneos/LUTCalcIOS.app/Info.plist` 均读回了同一套三/四方向和空字典启动屏配置。最终构建日志未再出现此前的 `All interface orientations must be supported` 或 `A launch configuration or launch storyboard or xib must be provided` 警告。

实际命令：

```sh
python3 tools/native-validation/verify-native-document-types.py
plutil -lint Native/Apps/iOS/Info.plist
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh
```

工具链 Xcode 27.0（27A266a）、Swift 6.4。完整入口中 9 项 Node 子集、3 项 App 包审计契约、34 项 XCTest、macOS/iOS Simulator/iOS generic 三个 Release 未签名构建及对应资源包审计通过；最终退出码仍为 2，原因是尚未具备 `docs/native-validation/full-scope-acceptance.json`，不计发布通过。本机日志 `/tmp/lutcalc-ios-plist-red-20260924.log` 和 `/tmp/lutcalc-ios-plist-release-20260924.log` 只作诊断，结论已写入本记录。此项无数值算法或夹具变动，故无新增误差结果。

修改版本 SHA-256：`Native/Apps/iOS/Info.plist` 为 `0594747f63a1f27ae2e1ddcf0de9049f53953649e3a1ba15b23f1a06fe4bb885`；`tools/native-validation/verify-native-document-types.py` 为 `66d25b22e27bbc7b7575655a8e57e9a509d40dba062d23a9e07cdf05393b6229`。已安装到 iPhone 的先前 Debug 包尚未按本次配置重新签名安装；iPhone/iPad 旋转、多窗口缩放与文档界面可用性需单独实测。
