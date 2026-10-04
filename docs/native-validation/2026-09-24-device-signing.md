# iPhone 真机签名阶段记录

日期：2026-09-24。状态：**iPhone Air 开发签名构建、安装与进程启动已通过；真机交互、数值生成、保存和导出仍未验收。** 此项不影响此前未签名 iOS generic/Simulator 与 macOS 构建通过的结论。

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcdevice list --timeout 10` 返回一台 `available: true` 的 iPhone Air（iOS 27.2，网络接口），另两台旧 iPhone 返回不可用。本轮只对可用设备尝试 Debug 开发签名构建；未安装到设备，也未读取或操作设备上的个人内容。

实际命令的关键参数：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'platform=iOS,id=<可用设备标识>' -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=<本机开发证书对应团队> build
```

对本机已有两组 Apple Development 证书团队分别执行，均在 `GatherProvisioningInputs` 后退出码 65、`BUILD FAILED`：Xcode 报 `No Account for Team`，且没有 `org.lutcalc.native.dev.ios` 的 iOS App Development provisioning profile。检查 `~/Library/MobileDevice/Provisioning Profiles` 也无现成文件。实际命令输出位于本机临时 `/tmp/lutcalc-device-sign-20260924.log` 与 `/tmp/lutcalc-device-sign-xjs-20260924.log`；上述诊断已落盘，临时日志不作为永久交付。

## 登录后重试与实际设备结果

用户确认已在 Xcode 登录后，再用旧证书团队 `555ZHJ6B72` 重试，仍在 `GatherProvisioningInputs` 失败，原因是该团队并非当前账户的团队。Xcode 设置显示当前账户拥有 `Lingru Miao Developer Team`；改用团队标识 `DD4V6SJ9XL` 后，Xcode 自动取得 `iOS Team Provisioning Profile: *`，用本机 Apple Development 证书完成 Debug 签名构建，日志显示 `BUILD SUCCEEDED`，退出码 0。`codesign -dv` 确认 App 标识 `org.lutcalc.native.dev.ios`、签名团队 `DD4V6SJ9XL`，没有将旧证书括号中的标识误作当前账户团队。构建有“必须支持全部方向”和“缺少启动配置”的 Xcode 警告，尚待平台界面验收时处理。

实际执行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'platform=iOS,id=00008150-0012709121D2401C' -derivedDataPath /tmp/lutcalc-device-derived -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=DD4V6SJ9XL build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device install app --device 00008150-0012709121D2401C /tmp/lutcalc-device-derived/Build/Products/Debug-iphoneos/LUTCalcIOS.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch --device 00008150-0012709121D2401C org.lutcalc.native.dev.ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device info processes --device 00008150-0012709121D2401C
```

安装命令退出码 0，设备报告 App 已安装。首次启动因设备锁定返回 `FBSOpenApplicationServiceErrorDomain`、`Locked`，不能计运行成功；用户解锁后重试退出码 0，报告 `Launched application`。随后进程清单有 `/LUTCalcIOS.app/LUTCalcIOS`（当次 PID 7174），证明并非只有安装或瞬时启动。没有取得 App 的真实屏幕交互、项目保存、CUBE 导出读回或真机数值误差结果，仍不勾选 H01/H08/H09/发布门槛。只查询了本 App 进程状态，没有读取设备个人文件。

工程版本 SHA-256：`Native/LUTCalc.xcodeproj/project.pbxproj` 为 `7120c086fc55d41357085f02f31a418f4050240aee7e2f9a02d0a799ce00223e`；`Native/Apps/iOS/LUTCalcIOSApp.swift` 为 `a2dbadcc4b2c5f1783ab13192c23dc6eeeddf14b45a5da8572ca5f11150b6e0d`。本机诊断日志在 `/tmp/lutcalc-device-sign-after-login-20260924.log`、`/tmp/lutcalc-device-sign-actual-team-20260924.log` 与 `/tmp/lutcalc-device-*.json`；关键结论已写入本记录，不依赖临时文件永久保存。

后续补充：上述两条首次 Debug 构建警告已在源码 Info.plist 中修正，三个未签名 Release 构建无对应警告；详见[iOS/iPadOS 启动与方向声明记录](2026-09-24-ios-platform-plist.md)。真机旧安装包未因此自动更新，不能将 Release 配置验证写成真机旋转验收。
