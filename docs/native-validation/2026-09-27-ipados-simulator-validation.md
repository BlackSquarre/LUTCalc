# 2026-09-27 iPadOS 模拟器启动与可访问性验收

## 范围

本轮只使用 iPad Air 11 英寸模拟器，运行时为 iOS 27.0；没有把该模拟器结果当作实体 iPhone 11 证据。设备使用独立临时 CoreSimulator 设备集，避免修改既有设备目录。

## 实际命令与结果

- `xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices create 'LUTCalc iPad Validation' 'com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3' 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'`，退出码 `0`，设备 UDID `008C5326-7CAA-471D-AF57-931B1BF0399D`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcIPadValidationDD CODE_SIGNING_ALLOWED=NO build`，退出码 `0`。
- 使用 `xcrun simctl install` 安装 `/tmp/LUTCalcIPadValidationDD/Build/Products/Debug-iphonesimulator/LUTCalcIOS.app`，使用 `xcrun simctl launch` 启动 `org.lutcalc.native.dev.ios`，进程实际运行。
- 首屏截图 `/tmp/lutcalc-ipad-launch-settled-20260927.png`，SHA-256 `c30d2c063c164b186a064a4d6e0bcb59895aa0eb0e892f7546e92d12214f9cea`；画面显示原生文稿浏览器和“创建文稿”。
- 设置 `content_size accessibility-large` 后截图 `/tmp/lutcalc-ipad-a11y-large-20260927.png`，SHA-256 `ace572e1bb74987c16fac3013b255bc10437c09c513b7aa9f4095295fbe258ba`；“创建文稿”仍可见，未观察到启动页文字互相遮挡。
- 复验同一临时设备集：重新安装并启动后等待稳定，`accessibility-large` 首屏截图 `/tmp/lutcalc-ipad-a11y-rerun-settled.png`，SHA-256 `a2c4c5c4a3fc255673aee56934a8f7f558789a759cff73080ed99919708098ee`；“创建文稿”、最近项目区域和大字号文字均可见。`simctl io enumerate` 仍报告主屏为 Portrait；通过启动参数请求横向未改变设备方向，因此不能计入旋转通过。
- 尝试用 `SIMULATOR_DEVICE_SET_PATH=/tmp/LUTCalcCoreSimulatorDevices xcodebuild ... -destination 'platform=iOS Simulator,id=008C5326-7CAA-471D-AF57-931B1BF0399D' -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testDocumentViewSurvivesRotationOnDevice test` 绑定旋转 UI Test，退出码 `70`；Xcode 27 仍只列默认设备集和实体设备，未发现该临时 UDID。Xcode 生成的临时 `.xcresult` 路径由工具输出，未产生可计入的测试结果包。

## 阻塞与未覆盖

- 该临时设备集未被当前 Xcode 27 `xcodebuild` destination 发现，针对 UDID 运行 UI Test 返回退出码 `70`，结果包未产生可计入的 UI 交互通过证据。
- 因此本轮只计入模拟器构建、安装、启动和大字号首屏检查；未勾选 iPad 多窗口、旋转、文稿协调、Files/File Provider、完整 VoiceOver、键盘导航或项目保存往返。
- 默认 CoreSimulator 设备目录位于 `/Volumes/4T/Xcode-Developer/User/CoreSimulator-Devices`。直接创建设备时日志报告 `NSCocoaErrorDomain 513`（无权写入该目录）；该权限问题是本轮环境阻塞，不修改目录权限，也不删除既有设备。
