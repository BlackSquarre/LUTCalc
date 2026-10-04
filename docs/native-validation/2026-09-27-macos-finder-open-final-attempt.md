# 2026-09-27 macOS Finder 直接双击最终复核

## 实际操作

使用 Finder 中已选中的 `/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc` 项目包，在 Finder 列表执行两次双击。Finder 选择仍停留在该项目包；LUTCalcMac 没有出现新的文稿窗口，原生 App 仍处于系统“打开”面板。未将此结果解释为项目字段重开。

此前同一窗口通过 LaunchServices 直接传入路径可以恢复 `schemaVersion=2`、`cubeSize=17`、`exposureStops=0.5`，但那不是 Finder 双击路径。本次 Finder 复核没有新的字段读回、截图或结果包。

## 判定与未覆盖

Finder 直接双击仍未取得正证据，Finder 重开验收保持未通过。该结果不否定已有系统文稿保存、关闭和 LaunchServices 路径恢复证据。外部替换竞争、iCloud/File Provider、Finder 多窗口和发布全量清单仍未覆盖。
