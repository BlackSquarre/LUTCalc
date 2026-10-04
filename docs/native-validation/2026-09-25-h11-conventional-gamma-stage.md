# H11 简单 Conventional Gamma 批次验收

日期：2026-09-25。状态：阶段通过；H11、CORE-03、FULL-01 和发布门槛仍未完成。

## 本批实现

本批将旧版 `js/gamma.js` 的 `LUTGammaGam` 简单“Linear / γ”曲线接入纯 Swift `TransformPlan` 和 `AlgorithmCatalog`。来源文件仍只作为可追溯公式参照，不打包旧脚本、`.labin` 或采样表。

新增 12 个稳定 ID 与别名：

`gamma.1-5.v1`（γ1.5）、`gamma.1-6.v1`（γ1.6）、`gamma.1-7.v1`（γ1.7）、`gamma.1-8.v1`（γ1.8）、`gamma.1-9.v1`（γ1.9）、`gamma.2-0.v1`（γ2.0）、`gamma.2-1.v1`（γ2.1）、`gamma.2-2.v1`（γ2.2）、`gamma.2-3.v1`（γ2.3）、`gamma.2-4.v1`（γ2.4）、`gamma.2-5.v1`（γ2.5）、`gamma.2-6.v1`（γ2.6）。

实现位于 `ConventionalGammaTransfer.swift`，保持 `Double`。公式保留旧版 legacy 0.2 灰标度、低端线性分支和幂律分支；输入输出的非有限值拒绝由契约覆盖。计划版本为 `legacy-conventional-gamma-v1`，不宣称 HDR/OOTF、设备参数或跨色域等价。

## 验证

- 定向 `ConventionalGammaContractsTests`：4 项通过。
- 定向注册表契约：1 项通过；12 个曲线均有来源、别名和可解析计划。
- 当前 `swift test --list-tests`：222 项。
- 完整 Release 入口：旧 Node 契约、Python 审计、批量公式检查、33³/65³ CUBE 生成及独立读回、macOS Release、iOS Simulator Release、iOS generic Release 和 3 个 App 包资源审计通过。
- 完整入口的发布证据检查仍退出码 2，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单。

## 限制与后续

本批只完成简单 γ1.5–γ2.6。ProPhoto、BBC、通用参数化 Gamma、HDR/OOTF、相机范围、真实设备运行、第三方软件往返、File Provider/Files 取消路径、完整 H11/CORE-03、FULL-01 和发布验收仍未完成。真机测试按用户安排集中到最后。
