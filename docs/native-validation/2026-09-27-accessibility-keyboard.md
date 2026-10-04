# SwiftUI 无障碍与键盘语义阶段验收

日期：2026-09-27。

## 修改

在 `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` 增加：

- 撤销、重做的 VoiceOver 提示和 `⌘Z`/`⇧⌘Z` 快捷键。
- 曝光 Double 输入、图像 X/Y 坐标和用户 LUT RGB 输入的明确无障碍标签与输入提示。
- 导出状态的无障碍标签和值。
- 生成 CUBE 按钮的 VoiceOver 标签、后台任务提示和 `⌘G` 快捷键。

这些改动只影响 SwiftUI 交互语义，不改变计算、文件格式、网格、插值或精度阈值。

## 实际验证

```text
swift test --package-path Native/Packages/LUTKit -c release
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

结果：Swift Release 测试、macOS Release、generic iOS Release 和 iOS Simulator Release 均退出码 `0`。

日志哈希：

```text
5efef0fe4135f031b5dd909d4f952404574033959c8e921b3e3ec739756d5df9  /tmp/lutcalc-accessibility-swift-release.log
0fd841386c4a62c1c914294d51eeec2be8eb52b0571cdebef1a007ce4dc2d9d8  /tmp/lutcalc-accessibility-mac.log
4e958bfb2cc27dae7117267897599402c5c79bbe976f4606ef12806df411271e  /tmp/lutcalc-accessibility-ios.log
a5fa2d34307374d86f7d5298e0233850f6b143d8d939517c45bd7d8004a289c8  /tmp/lutcalc-accessibility-iossim.log
```

## 未覆盖

本阶段没有取得 VoiceOver 真机逐项朗读、动态字体、iPad 多窗口或完整键盘导航 UI 证据；UI-07 仍未完成。
