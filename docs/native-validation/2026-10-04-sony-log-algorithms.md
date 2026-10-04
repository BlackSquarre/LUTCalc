# 2026-10-04 Sony S-Log／S-Log2 算法验收

## 范围与裁决

本包只闭合旧清单中已有的 Sony `S-Log`、`S-Log2` 两条传递曲线，分别提供公开反射率域和 LUTCalc 旧线性域身份；补齐既有 Sony S-Gamut 色域身份与 NEX-FS700、a7s、PMW-F3 的默认路由。没有新增厂商风格、色温特定 IDT 或完整 ACES 工作流。

公开身份在反射率边界使用历史 Sony／Colour Science 约定的 `0.9` 适配：输入 scene 反射率先除以 `0.9`，旧身份直接使用 LUTCalc 的灰 `0.2` 线性域。适配只在 TransformPlan 场景边界发生一次。传递参数来自旧注册表中原有解析式，并由固定版本的 Colour Science `sony.py` 及 Sony 提供的 ACES S-Log2 daylight IDT 交叉核对。S-Log2 的 Sony IDT 还区分 10/12 位和 daylight/tungsten；本包只实现连续 Double 传递函数，不能把 daylight 矩阵当成所有色温设备的完整 IDT。

来源归档：`research/colour/2026-10-04/algorithm-sources/`。其中 `colour-sony.py` 固定 Colour Science commit `ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5`，两个 Sony S-Log2 daylight CTL 固定 ACES dev commit `710ecbe52c87ce9f4a1e02c8ddf7ea0d6b611cc8`；URL、大小、SHA-256 和 `runtime_allowed=false` 在 `manifest.json`。来源只留在研究目录，不进入 App。

## 实现与契约

- 新增 `SonyLegacyLogTransfer`，含 `sony.slog.v1`、`sony.slog.lutcalc-legacy.v1`、`sony.slog2.v1`、`sony.slog2.lutcalc-legacy.v1`。
- `TransformPlan`、`NativeOutputEncoder`、`OutputCodeUnits`、目录、项目身份和 CLI 均按实际 ID 接线；Sony S-Gamut 原色独立登记为 `sony.sgamut.v1`，不把 S-Gamut 冒充 S-Gamut3。
- 契约覆盖灰点、正负 toe、分界相邻值、非有限值、公开／旧域差异、一次边界标度和相机默认路由。没有裁剪负值，也没有改变网格、位宽、插值或误差阈值。
- 独立参照脚本为 `tools/native-validation/sony-log-reference.py`，Decimal 精度 90 位，逐节点验证同 transfer 曝光一档计划。

## 实际结果

证据目录：[2026-10-04-sony-log-contracts](artifacts/2026-10-04-sony-log-contracts/)。

- Debug 定向 Sony 契约 3 项通过；Swift Release 全量执行 **697 项、0 失败**（相对前一包增加 3 项；LUTFormats 外部夹具的 2 项跳过保持不变）。完整日志为 `swift-release-full.log`。
- 四个身份分别生成 17³、33³、65³，共 **12 个 CUBE、1,261,900 节点、3,785,700 通道**。独立 90 位 Decimal 逐通道验证全部通过，最大尺度化误差 **`1.9981344709861718e-16`**，固定门槛 `2e-12`。每个网格的最大、RMS、P99 在 `cube-decimal-summary.json`。
- macOS、generic iOS、generic iOS Simulator Release 构建均产生目标 App；Simulator 服务本轮仍记录系统 `Cannot allocate memory` 诊断，但构建产物和退出日志均保留。三套 App 包审计通过，155 个生产 Swift 源码审计通过。
- 目录最终为 **60 曲线、19 色域、56 预设、66 相机身份**；`LUTCatalogChecks` 通过。
- CUBE 真文件、SHA-256 清单、命令列表、构建日志和独立脚本均保存在证据目录。研究来源和 CUBE 没有加入 App 资源。

## 未覆盖

Sony S-Log3 已有独立验收；本包不替代 S-Log3 的官方／旧兼容证据。S-Log2 的 daylight/tungsten 矩阵、Sony Venice 专用 primaries、完整 ACES IDT、相机 EI／sensor／高光裁剪和目标软件往返仍需分别验收。其他既有未闭合算法（Canon C-Log／CP IDT、REDLogFilm、Blackmagic Pocket Film、DJI 旧曲线、SUP2 校准、HDR/OOTF、完整 ICC、LUTAnalyst 和直接查表台账）没有在本包中处理。Goal 保持 active。
