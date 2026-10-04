# 2026-09-27 iPadOS 模拟器验收重试

## 范围

本轮按用户要求只尝试 iPadOS 模拟器，不使用其他真机或 iPhone 镜像替代。目标是取得 iPad 文稿入口、旋转、多窗口和文稿协调的可执行 UI 证据。

## 工具链与静态契约

- Xcode `27.0`（`27A266a`），Apple Swift `6.4`。
- `python3 tools/native-validation/verify-native-document-types.py` 退出码 `0`；日志 `/tmp/lutcalc-ipad-document-types.log`，SHA-256 `abaf2dc3d005317c73aedf2da23f663e09221136353bec4b50dd99784b7af1c3`。
- 该检查确认 `org.lutcalc.project` package 文档类型、iOS 原位打开、iPhone 三方向、iPad 四方向和 `UILaunchScreen` 声明完整。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcIPadGeneric-20260927 CODE_SIGNING_ALLOWED=NO build`
  - 退出码 `0`。
  - 日志 `/tmp/lutcalc-ipad-generic-build-20260927.log`，为空日志，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- 以上只证明 iPad 架构可编译和平台声明静态正确，不证明 UI 交互。

## 模拟器设备集路径复验

当前唯一可用运行时为 iOS `27.0`（`24A5390f`），`xcrun simctl list devices available` 没有已创建设备。使用 iPad Air 11-inch M4 尝试创建：

```text
xcrun simctl create 'LUTCalc iPad Temp Validation' 'com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4' 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
```

- 退出码 `22`，日志 `/tmp/lutcalc-ipad-temp-create.log`，SHA-256 `32029efe1589b8c19088d2fca37fba4a993a036c88cc50a98718f6709c659169`。
- 另一次创建 `LUTCalc iPad Validation 20260927` 也返回同一错误；没有得到可启动 UDID，未产生可计入的 UI 测试结果包。
- CoreSimulator 日志 `/Users/lingru/Library/Logs/CoreSimulator/CoreSimulator.log`，SHA-256 `cd9b75a968edbaf174365c477af0f92c66d6f1573d5941874f57d3534c94459f`，明确记录：设备目录为 `/Volumes/4T/Xcode-Developer/User/CoreSimulator-Devices`，复制样板返回 `NSCocoaErrorDomain Code=513`（`Operation not permitted`），随后设备卡在 creation state 并被删除。
- 17:47 再次在默认设备集创建 iPad Air 11-inch M3 仍失败，退出码 `22`；日志 `/tmp/lutcalc-ipad-default-create-retry.log`，SHA-256 `2413057e6f67781dac5619e160c54b40602a273298750bda08804a8700b67ba7`。最新 CoreSimulator 日志仍为 Code=513 / POSIX Code=1，未改变独立设备集可用、Xcode destination 不可见的结论。
- 曾通过 `SIMULATOR_DEVICE_SET_PATH=/tmp/LUTCalcCoreSimulatorDevices-20260927` 指定独立目录重试，仍由当前 CoreSimulator 服务回落到上述外置设备集并失败；该环境变量不是本次有效的设备集选择方式。

随后改用 `xcrun simctl --set` 显式指定设备集，创建和启动成功：

```text
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20260927b create \
  'LUTCalc iPad 27 Followup' \
  'com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3' \
  'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
```

- 设备 UDID：`CD363B59-923B-471D-B47F-64792492CE9C`；`simctl --set ... list devices available` 报告设备 Booted。
- 使用已通过的 iOS Simulator Debug App 安装并启动成功，进程实际运行。
- 稳定首屏截图 `/tmp/lutcalc-ipad-followup-settled.png`，1640×2360 RGBA，SHA-256 `230f2ce920fda4ebd039d11d186221181d1be89fb861d7156a9b052eb636cb81`；画面显示原生文稿浏览器、“创建文稿”和最近项目区域。
- 设置 `content_size accessibility-large` 后截图 `/tmp/lutcalc-ipad-followup-a11y-large.png`，SHA-256 `ea6465ca6ff74c01dfdf0df79d5deb84a649295f9156846513f772a02b5c442a`；“创建文稿”仍可见，未观察到首屏遮挡。
- `xcodebuild -showdestinations` 仍只列默认设备集和实体设备。实际运行 `xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'platform=iOS Simulator,id=CD363B59-923B-471D-B47F-64792492CE9C' -destination-timeout 1 -derivedDataPath /tmp/LUTCalcIPadValidationDD CODE_SIGNING_ALLOWED=NO -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testDocumentViewSurvivesRotationOnDevice test`，退出码 `70`；日志 `/tmp/lutcalc-ipad-followup-destination.log`，SHA-256 `0c9d17e7cd50446113367a55a16033ceb601194576e2ac6d52df45609548df4f`，明确报 `Unable to find a device matching the provided destination specifier`。测试方法没有执行；没有可计入的旋转、多窗口或文稿协调 XCTest 结果包。

## 2026-09-27 晚间设备集复验

使用同一独立设备集再次确认设备仍为 Booted：

```text
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20260927b list devices
```

输出仍为 iOS 27.0 的 `LUTCalc iPad 27 Followup`（UDID `CD363B59-923B-471D-B47F-64792492CE9C`）。从该设备集截取的当前原生文稿编辑页为 `/tmp/lutcalc-ipad-current-20260927.png`，1640×2360 RGBA，SHA-256 `1205fee90ca7704cbb88bc61c2f111d940686b5dd7803e0ee7f3265b5a812e5d`；画面可见文稿名称、D-Log2、D-Gamut2、Data、曝光 `0.5` 和生成 CUBE 按钮。

该复验没有改变 Xcode destination 服务不可发现独立设备集的状态，也没有把 `simctl` 截图当作旋转、多窗口、VoiceOver 或键盘导航的通过证据。

## 未覆盖范围

本轮计入模拟器设备创建、安装、启动和大字号首屏检查；未覆盖 iPad 文稿创建、旋转、多窗口、系统 Files、VoiceOver、键盘导航或项目保存重开。设备集选择结论是：`xcrun simctl --set <目录>` 有效，`SIMULATOR_DEVICE_SET_PATH` 对当前 CoreSimulator 服务无效；Xcode destination 发现仍是独立阻塞。在此之前 H09/H12、UI-07 和 iPad 相关 FULL/QA 项继续保持未完成。
