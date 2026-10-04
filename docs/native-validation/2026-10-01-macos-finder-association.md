# 2026-10-01 macOS Finder 文稿关联复核

## 环境与夹具

- 工具链：Xcode 27.0（27A266a），macOS arm64。
- 构建命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcFinderOct1DD CODE_SIGNING_ALLOWED=NO build > /tmp/lutcalc-finder-oct1-build.log 2>&1`；退出码 `0`，日志 SHA-256 为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- 从既有 `2026-09-24-mac-roundtrip.lutcalc` 研究夹具生成 `/tmp/LUTCalc-finder-oct1.lutcalc`，更新至 schema 2 并添加空 `assetRoles`。`manifest.json` SHA-256 为 `620a24c998d45411fdca52c60b6c39d638c3c39972d8950c410ef27ffde0a861`。该夹具与 9 月 27 日系统保存的项目不同，不能替代实际新建保存往返证据。
- `mdls` 将夹具识别为 `org.lutcalc.project`，种类为 `LUTCalc Project`。构建包 `Info.plist` 声明了 `CFBundleDocumentTypes`、`org.lutcalc.project`、Editor、Owner 及包文稿类型。

## Finder 实际操作与结果

1. 确认 `LUTCalcMac` 进程未运行。在 Finder 的 `/tmp` 列表中直接双击夹具，系统弹出“未设定用来打开文稿的应用程序”警告；没有打开项目。
2. 执行 `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /tmp/LUTCalcFinderOct1DD/Build/Products/Debug/LUTCalcMac.app` 后，Finder 再次直接双击，仍出现同一警告。
3. 从警告中的“选取应用程序…”进入系统面板，按构建包的完整路径选择 `LUTCalcMac.app`，系统说明“此应用程序可以打开”该文稿。点击“打开”后，进程启动且项目窗口标题为 `LUTCalc-finder-oct1.lutcalc`，窗口 URL 指向夹具。界面显示输入 D-Log2／D-Gamut2、曝光 `0.5`、目标线性 ACES AP0、输出 Linear scene／ACES AP0、3D 尺寸 `17³` 和导出 CUBE。
4. 关闭项目窗口后，回到 Finder 对同一夹具直接双击，系统仍弹出“未设定用来打开文稿的应用程序”警告。因此一次“选取应用程序”仅证明显式指定 App 可以打开文稿，未建立可持续的 Finder 默认关联。

## 判定

夹具与构建日志已复制到 [证据目录](artifacts/2026-10-01-finder-association/)。Finder 交互观察来自本轮桌面自动化工具的实际窗口与无障碍树，未取得设备 XCTest 结果包。

本轮把先前“Finder 双击没有新窗口”的现象缩小到系统未设置默认打开应用。显式选择构建包的文稿恢复与字段读回通过；**Finder 直接双击重开仍未通过**。调试构建位于临时目录，且未完成发布安装、签名及关联验证；本轮没有将临时 App 永久设为用户的默认应用。H12/FLOW-04 的 Finder 直接打开项继续保持未完成。此次操作没有数值误差测量，也没有覆盖 iCloud/File Provider、多窗口或完整发布验收。
