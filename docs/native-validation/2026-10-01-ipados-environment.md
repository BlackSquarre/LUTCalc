# 2026-10-01 iPadOS 模拟器环境复验

## 实际命令与结果

工具链为 Xcode 27.0（27A266a），运行时为 iOS 27.0（24A5390f）。默认设备集仍无已创建模拟器。本轮使用独立设备集：

```sh
mkdir -p /tmp/LUTCalcCoreSimulatorDevices-20261001
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20261001 create 'LUTCalc iPad 27 Oct1' 'com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3' 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20261001 boot 7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20261001 bootstatus 7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21 -b
```

创建、启动和 bootstatus 均退出 `0`，UDID 为 `7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21`。随后执行：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcIPadOct1DD CODE_SIGNING_ALLOWED=NO build
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20261001 install 7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21 /tmp/LUTCalcIPadOct1DD/Build/Products/Debug-iphonesimulator/LUTCalcIOS.app
xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20261001 launch 7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21 org.lutcalc.native.dev.ios
```

构建、安装与启动均退出 `0`，启动 PID 为 `3971`。稳定截图显示原生文稿浏览器、“创建文稿”和空的最近项目区域。截图为 1640×2360，SHA-256 `30693b906f47bd005356237a4fff4bff8ae04fda3ced08ac46562567e20c1921`。截图仅证明入口已呈现。

## 旋转契约执行阻塞

已有旋转契约为 `LUTCalcIOSUITests/testDocumentViewSurvivesRotationOnDevice`。本轮实际执行：

```sh
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'platform=iOS Simulator,id=7BA0CDF5-B4CE-4D33-ACBB-9D679416FF21' -destination-timeout 1 -derivedDataPath /tmp/LUTCalcIPadOct1TestDD -resultBundlePath /tmp/LUTCalcIPadOct1Rotation.xcresult CODE_SIGNING_ALLOWED=NO -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testDocumentViewSurvivesRotationOnDevice test
```

退出码 `70`：`Unable to find a device matching the provided destination specifier`。`-showdestinations` 也没有该独立 UDID。虽然命令报告写入结果包路径，测试方法没有执行，不能计入 XCTest 通过证据。当前 `/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app` 不存在，启动图形 Simulator 的尝试以文件不存在失败，因此没有得到通过 Simulator 窗口交互完成旋转的替代证据。

## 已保存证据与判定

实际日志与截图已复制到 [证据目录](artifacts/2026-10-01-ipados-environment/)。

| 文件 | SHA-256 |
| --- | --- |
| `lutcalc-ipad-oct1-build.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `lutcalc-ipad-oct1-destinations.log` | `f18a0cd0ef4fb061c1a46740c4ef4036725e019eabc8cfc20c754ff0e9beb6e9` |
| `lutcalc-ipad-oct1-rotation.log` | `1091924e24e5b9c26fd6975d82bf095da0ec5f461b1f822eae3c546c7a1a4001` |

本轮没有数值误差测量。旋转、多窗口、文稿协调、VoiceOver、键盘导航和 iPad Files/File Provider 的实际 UI 验收继续未完成；未使用任何 iPhone 或真机替代。Goal 保持 active，未创建全量发布清单。
