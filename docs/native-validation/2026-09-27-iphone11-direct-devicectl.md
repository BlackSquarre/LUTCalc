# 2026-09-27 iPhone 11 直接开发者工具验证

## 设备

- 设备：实体 iPhone 11（`iPhone12,1`）
- UDID：`00008030-001015101ABA802E`
- 连接方式：有线，`xcrun devicectl`
- Developer Mode：已启用
- 系统：iOS 26.5（23F77）
- 本次未使用 iPhone Air、iPhone 镜像或模拟器。

## 实际命令与结果

1. `xcrun devicectl list devices`：确认 iPhone 11 为 `connected`，且 Developer Mode 已启用。
2. `xcodebuild -scheme LUTCalcIOS -project Native/LUTCalc.xcodeproj -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-iPhone11 CODE_SIGNING_ALLOWED=NO build`：退出码 0，生成未签名 App。
3. 使用本机已安装的 wildcard provisioning profile（UUID `31274238-cf7f-4713-9d5c-5cb15f76bbc0`，设备 UDID 在授权列表中）和开发证书指纹 `C1E5A27C020ED418695E7A772AEE8872044DD62A` 对 App 签名；`codesign --verify --deep --strict` 通过。
4. `xcrun devicectl device install app --device 00008030-001015101ABA802E /tmp/LUTCalc-iPhone11/Build/Products/Release-iphoneos/LUTCalcIOS.app`：退出码 0，设备报告 `App installed`。
5. `xcrun devicectl device process launch --device 00008030-001015101ABA802E org.lutcalc.native.dev.ios`：退出码 0，设备报告 `Launched application`。
6. `xcrun devicectl device capture screenshot --device 00008030-001015101ABA802E --destination /tmp/lutcalc-iphone11.png`：退出码 0，生成 828×1792 PNG。

## 观察结果

截图显示原生 SwiftUI 启动界面：标题“LUTCalcOS”、按钮“创建文稿”、最近项目/共享/浏览区域均可见，未出现启动崩溃或空白屏。该证据确认的是 iPhone 11 上的安装、启动和首屏渲染；尚未覆盖系统 Files 实际写入回查、项目关闭/重开、取消导出、VoiceOver、动态字体、后台恢复和完整业务链路。

## 仍未完成

本记录不替代完整 H01–H14 或发布验收。`docs/native-validation/full-scope-acceptance.json` 仍不能伪造；任意 3D LUT 反求、完整 ICC/显示色彩管理、iPad 真机/多窗口、macOS Finder 往返、目标软件往返、性能与发布签名等项目仍保持未完成。
