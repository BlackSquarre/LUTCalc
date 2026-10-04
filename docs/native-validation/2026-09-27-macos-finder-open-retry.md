# 2026-09-27 macOS 项目直接打开复验

## 范围

本轮继续使用 `/tmp/LUTCalcMacFinderDD/Build/Products/Debug/LUTCalcMac.app` 和项目包 `/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc`。目标是区分 Finder 双击路径与 LaunchServices 直接传入文稿路径的行为；不把后者扩大解释为 Finder 双击证据。

## 实际操作与结果

1. Finder 列表中选中 `LUTCalc-mac-roundtrip-20260927.lutcalc`，执行双击；Finder 选择状态保持不变，Debug App 仍显示系统“打开”面板，没有出现文稿窗口。该尝试记为未通过。
2. 检查到另一个相同 bundle identifier 的 Release App 进程正在运行，结束该进程后再次从 Finder 双击，仍未出现文稿窗口。
3. 通过 LaunchServices 将同一项目路径直接传给 Debug App 后，App 创建文稿窗口，窗口标题为 `LUTCalc-mac-roundtrip-20260927.lutcalc`。界面读取到：输入 D-Log2 / D-Gamut2、曝光 `0.5`、输入范围 Data、输出线性 ACES AP0、3D 尺寸 `17³`、导出格式 CUBE。

## 判定

- 直接传入文稿路径的系统文稿协调与字段恢复通过，和磁盘清单中的 `schemaVersion=2`、`cubeSize=17`、`exposureStops=0.5` 一致。
- Finder 直接双击本轮仍未取得新的正证据；不勾选 Finder 双击验收，不改变既有“历史重开证据”记录。
- 同 bundle identifier 的并行 Release App 会影响 LaunchServices 路由，后续若重测必须保证只运行目标构建。

## 未覆盖

本轮未覆盖 Finder 外部替换竞争、iCloud/File Provider 授权失效、后台恢复、多窗口和目标软件往返。

## 后续 Finder 选择项打开复核

在 Debug App 中先关闭已打开的项目窗口，再在 Finder 选中同一项目包，执行 `tell application "Finder" to open selection`。未出现新的文稿窗口；当时另有同 bundle identifier 的 Release App 进程，无法排除路由干扰。该操作不是鼠标双击，也没有重新取得项目字段的界面读回，因此不计为 Finder 双击通过。后续再次尝试检查原生界面时，Mac 处于锁屏且自动解锁失败，未执行新的 Finder 操作；仍需在可操作桌面且只运行目标构建时复验。
