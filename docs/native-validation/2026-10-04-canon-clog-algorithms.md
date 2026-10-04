# 2026-10-04 Canon C-Log 算法验收

## 范围与裁决

本包只闭合旧清单中已有 `C-Log` 的解析式兼容路径。旧 `js/gamma.js` 将其注册为 `LUTGammaLog`，原生版保存 `canon.c-log.lutcalc-legacy.v1` 独立身份，保留九参数分段式和 LUTCalc legacy 灰 `0.2` 线性域。没有把该兼容式称为 Canon 官方 C-Log，也没有把 `Canon CP IDT (Daylight/Tungsten)` 的 `.labin` 输出表拟合成算法。

CP IDT 仍是单独研究阻塞：现有仓库包含 `cpoutdaylight.labin`、`cpouttungsten.labin` 和 `CSCanonIDT` 的矩阵/调节路径，但本包没有移植查表数据或声称已经恢复其完整连续变换。公开 Canon C-Log、设备矩阵、曝光 shoulder 和 CP IDT 需分别取得来源并独立验收。

## 实现与契约

- 新增 `CanonCLogTransfer`，只提供 legacy encode/decode。
- 接入 `TransformPlan`、`NativeOutputEncoder`、显式 code-unit 分类、目录、项目身份、legacy 相机默认路由和 `LUTReferenceCLI`。
- 契约覆盖分段边界、负值、非有限、计划路由、目录和相机状态。
- `tools/native-validation/generate-canon-clog-legacy-reference.js` 直接运行旧 `js/gamma.js` 生成研发夹具；`tools/native-validation/canon-clog-reference.py` 使用 90 位 Decimal 验证 CUBE。两者都不会进入 App。

## 实际结果

证据目录：[2026-10-04-canon-clog-contracts](artifacts/2026-10-04-canon-clog-contracts/)。

- Canon 定向契约 **3 项**通过；Swift Release 全量 **702 项、0 失败**，LUTFormats 的 2 项既有外部夹具跳过。
- Legacy C-Log 生成 17³、33³、65³ 三个 CUBE，共 **315,475 节点、946,425 通道**；独立 Decimal 最大尺度化误差 **`2.1016030534279782e-16`**，门槛保持 `2e-12`。
- macOS、generic iOS、generic iOS Simulator Release 构建产物生成；三个 App 包审计和 157 个生产 Swift 源码审计通过。Simulator 日志保留 CoreSimulator 的系统内存不足诊断。
- 当前目录为 **63 曲线、20 色域、59 预设、66 相机身份**；`LUTCatalogChecks` 通过。

## 未覆盖

Canon 官方 C-Log 公式、Canon CP IDT、`cpoutdaylight`/`cpouttungsten`、完整 Canon Cinema Gamut 设备语义、C-Log 相机高光处理和目标软件往返仍未完成。其余查表替代、`.labin`、HDR/OOTF、完整 ICC、LUTAnalyst、UI、真机性能和发布验收不在本包范围内。Goal 保持 active。
