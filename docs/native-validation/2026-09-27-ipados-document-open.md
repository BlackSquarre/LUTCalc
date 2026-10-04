# 2026-09-27 iPadOS 模拟器文稿 URL 打开验收

## 范围

本轮只使用独立 CoreSimulator 设备集中的 iPad Air 11-inch M3（iOS 27.0，UDID `CD363B59-923B-471D-B47F-64792492CE9C`）。通过 `simctl` 将已由 macOS 系统保存的 `.lutcalc` 项目复制到 iOS App 数据容器，再以文件 URL 冷启动打开。该方法用于验证原生文稿协调和字段恢复，不把结果扩大解释为 XCTest、旋转、多窗口或实体设备证据。

## 夹具与工具链

- Xcode `27.0`（`27A266a`），Apple Swift `6.4`。
- 设备集：`/tmp/LUTCalcCoreSimulatorDevices-20260927b`。
- App：`org.lutcalc.native.dev.ios`。
- 源项目：`/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc`。
- 源 `manifest.json` SHA-256：`d3d98f2f814179872fcf1efc35b185c1e2f64c637ed5b258959f3d4d8a29d8d4`。
- 复制后的容器文件：`Documents/LUTCalc-ipad-open-20260927.lutcalc/manifest.json`；SHA-256 保持 `d3d98f2f814179872fcf1efc35b185c1e2f64c637ed5b258959f3d4d8a29d8d4`。

## 实际命令与结果

先行契约：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'LUTProjectTests.ProjectContractsTests'
```

退出码 `0`，`ProjectContractsTests` 8 项通过、0 失败；日志 `/tmp/lutcalc-ipad-document-project-contracts.log`，SHA-256 `26bfb4f7aec5e3f19bf68a8d3cdd4fddc391996f396033585a9151a384b26a38`。

```sh
UDID=CD363B59-923B-471D-B47F-64792492CE9C
SET=/tmp/LUTCalcCoreSimulatorDevices-20260927b
CONTAINER=$(xcrun simctl --set "$SET" get_app_container "$UDID" org.lutcalc.native.dev.ios data)
mkdir -p "$CONTAINER/Documents"
cp -R /tmp/LUTCalc-mac-roundtrip-20260927.lutcalc \
  "$CONTAINER/Documents/LUTCalc-ipad-open-20260927.lutcalc"
xcrun simctl --set "$SET" terminate "$UDID" org.lutcalc.native.dev.ios
xcrun simctl --set "$SET" openurl "$UDID" \
  "file://$CONTAINER/Documents/LUTCalc-ipad-open-20260927.lutcalc"
sleep 5
xcrun simctl --set "$SET" io "$UDID" screenshot /tmp/lutcalc-ipad-document-open-cold.png
```

- App 冷启动和文件 URL 打开命令均退出码 `0`。
- 截图 `/tmp/lutcalc-ipad-document-open-cold.png`：1640×2360 RGBA；SHA-256 `a9f21add1d9f12771aeba476297c9622603f961342e71cffa57279d3b549d946`。
- 截图中的原生 SwiftUI 文稿界面显示：项目名 `LUTCalc-ipad-open-20260927.lutcalc`、输入曲线 `D-Log2`、输入色域 `D-Gamut2`、曝光 `0.5`、输入范围 `Data`、范围位深 `10 位`，并显示“生成 CUBE”入口。
- 磁盘清单与界面字段一致；没有通过截图推断未显示的字段。

## 第二份文稿冷启动复核

为避免同一项目 UUID 被系统视为同一文稿，复制了第二份临时夹具并只把 `manifest.json` 的 `id` 改为 `BBA16960-F5B4-4057-AF22-CB3CB95B0FC7`；修改后清单 SHA-256 为 `4f56d8aad269590c5c649030f213bd964cfe8c5a931ecaa108e12c5bdc47dbd7`。终止 App 后以第二份文件 URL 冷启动，截图 `/tmp/lutcalc-ipad-second-unique-cold.png` SHA-256 为 `bbf30d808369a923b473da979f215c81e332e2f77f5a3e5d1b11705717caed21`，界面标题显示 `LUTCalc-ipad-second-unique-20260927.lutcalc`，其 D-Log2、D-Gamut2、曝光 `0.5` 等字段恢复。

这证明不同项目身份的冷启动 URL 可分别打开；同时打开两个窗口或 iPad 分屏仍未取得证据。对第二份 URL 在第一份文稿已显示时发送，界面没有切换到第二份，不能解释为多窗口成功。

## 未覆盖范围

本轮没有产生 Xcode UI Test 结果包；未覆盖 iPad 旋转、多窗口并行文稿、系统 Files 选择器、VoiceOver 逐项朗读、键盘导航、外部替换竞争、iCloud/File Provider 授权失效或后台终止恢复。独立设备集仍未被 `xcodebuild` destination 发现。

## 原生数值回归

文稿验收后执行 `bash Scripts/verify-native-numerics.sh`，退出码 `0`；日志 `/tmp/lutcalc-verify-native-numerics-20260927-rerun.log`，SHA-256 `960011575b13cfee42966476fe8d8aef98f2c435aed2ec750a4aeb172eeff1ab`。H08/H09/H10/H12 契约和原生子集命令行检查均通过；该回归不扩大 iPad UI 或完整发布范围。
