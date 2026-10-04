# macOS 原生项目界面保存与重开阶段验收

日期：2026-09-24。状态：**macOS `DocumentGroup` 功能草稿中的新建、修改、系统保存、关闭、重新打开和设置读回通过；iOS/iPadOS 对应保存流程尚未验收。** 本次只操作本 App 的临时测试项目，没有修改用户既有项目。

已有 `ProjectContractsTests`、`SessionContractsTests`、`LUTProjectSessionChecks` 为项目包内容、编辑会话和保存冲突提供了契约；本阶段追加真实系统界面链路验证，没有改写测试阈值。Xcode 27.0/Swift 6.4 的当前 `LUTCalcMac` 构建在系统“打开”面板点击“新建文稿”，默认 D-Log2/D-Gamut2、线性 AP0、17³。将曝光由 `1.0` 改为 `0.5` 并点“应用曝光”，界面出现可撤销与已编辑状态。通过系统保存面板将项目保存为 `/tmp/lutcalc-h12-mac-roundtrip-20260924.lutcalc`，窗口随后显示该文件 URL 和已保存状态。磁盘上出现目录包及 `manifest.json`，其 `schemaVersion=1`、`cubeSize=17`、`exposureStops=0.5`、输入/输出稳定 ID 均与界面一致。关闭窗口后，系统打开面板将其识别为 `LUTCalc Project`；重开同一路径，界面显示曝光 `0.5` 且撤销按钮为禁用，证明来自磁盘的新会话。

保留[该测试项目清单](artifacts/2026-09-24-mac-roundtrip.lutcalc/manifest.json)，SHA-256 为 `5c0093ab57b4b3a64b5ef75dee1306fad0328205bdd8ff826a863db5785d53b0`。对应界面源码 `ProjectDocumentView.swift` 为 `14fa4de69ae1b4314ac1db22d41341092456dd5a0ec7bde29b85da7b42a61859`，文档适配 `LUTProjectDocument.swift` 为 `b893c839c24d4bf2ac473c5d3f1145bdda52c185f50c3eda4abc1c8675b841dd`。原生项目包不含 LUT 资产；此证据仅是用户设置的序列化测试输出，不作为 App 内置内容。

同时使用 Xcode 27.0 的 iPad Air 13-inch (M4)、iPadOS 27.0 模拟器：`simctl boot`、`bootstatus -b`、`install`、`launch` 均退出码 0，进程返回 PID 90866。`simctl io screenshot` 取得的[首次启动截图](artifacts/2026-09-24-ipad-document-browser.png)显示原生“创建文稿”入口与空的最近项目列表，SHA-256 为 `b78af26ec00350e2a39fe878d28373c0a21ee7b92e4c78559ab3d40dbb2f21c4`。模拟器交互窗口未能通过当前电脑控制接口连接，因此没有点击创建，也不能据首次启动声称 iPad 的项目保存和重开通过。

实际平台命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot 4744E7F2-0E11-4D34-B6BC-03DB4C4D4607
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus 4744E7F2-0E11-4D34-B6BC-03DB4C4D4607 -b
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install 4744E7F2-0E11-4D34-B6BC-03DB4C4D4607 /Users/lingru/Library/Developer/Xcode/DerivedData/LUTCalc-fimnlmypznxigybkurjgwexeryfh/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch 4744E7F2-0E11-4D34-B6BC-03DB4C4D4607 org.lutcalc.native.dev.ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io 4744E7F2-0E11-4D34-B6BC-03DB4C4D4607 screenshot /tmp/lutcalc-ipad-sim-20260924.png
```

本阶段无新数值算法或误差结果；项目设置完整性以磁盘清单与重开界面一致为证。未覆盖：iPhone/iPad Files 与第三方 File Provider、App 崩溃或设备重启后重开、项目资产协调、多窗口冲突的实际平台交互、磁盘空间不足及用户最终 UI 设计。H12/APP-04/FLOW-04 尚未整体完成。
