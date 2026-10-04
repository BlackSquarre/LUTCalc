# H11 Rec.2100 PQ 标量与原生计划阶段验收

日期：2026-09-25。范围：加入 SMPTE ST 2084 / ITU-R BT.2100 PQ 的纯 Swift Double 标量转换，并登记到原生算法目录。此段只覆盖归一化绝对亮度标量与同空间计划，不宣称完成屏幕 HDR/EDR 显示。

## 先失败契约

先增加 `NumericContractsTests.testRec2100PQStandardScalarContract`，覆盖黑位、1/100/10000 cd/m² 对应的归一化值、10/12-bit 码值批次、域外和非有限输入。实现前 Release 构建因缺少 `PQTransfer` 失败；日志 `/tmp/lutcalc-pq-red.log`，SHA-256 `53c6b03e70a37095fd89547443e9cbbee8df9761f728a853aa036e01ed3f809f`。

## 实现与定向验证

新增 `PQTransfer`，使用公开 BT.2100/ST 2084 常数 `m1/m2/c1/c2/c3`，输入输出均保持 Double。输入亮度是相对 10,000 cd/m² 的 `[0,1]` 归一化值；显示峰值、OOTF、EDR 映射和屏幕色彩管理留在显示管线，不在这个标量函数中猜测。`TransformPlan` 已支持 `.rec2100PQ` 的解码/编码，同空间 Rec.2020 参考预设已登记。

`swift test -c release --package-path Native/Packages/LUTKit --filter 'RegistryContractsTests|NumericContractsTests/testRec2100PQStandardScalarContract'`：12 项通过、0 失败；日志 `/tmp/lutcalc-pq-catalog.log`，SHA-256 `da95de33a86e3ccb64faaace370a7af011bf32fd1ca040eeb8da69cff24f8e6e`。目录命令 `LUTCatalogChecks` 通过，20 曲线、12 色域、20 预设；日志 `/tmp/lutcalc-pq-catalog-check.log`，SHA-256 `49b799304a3fb21eb78649b15572f34175c5be6514adaf66bb24c01053dfb49e`。

## 边界

PQ 已进入可追溯算法目录和 Double 计划，但 PQ 屏幕显示、HDR/EDR 峰值参数、OOTF、真机显示测量和完整 UI 流程仍未验收；UI-06、H11 完整 HDR 范围和发布门槛继续保持未完成。

## 合并回归

`bash tools/native-validation/verify-native-release.sh` 的代码、Swift Release 测试、公式检查、33³/65³ 批量逐节点读回、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包审计均通过；公开 NCP 实样 1 项按无路径配置跳过。日志 `/tmp/lutcalc-h11-pq-release-20260925.log`，SHA-256 `3ab242376d8f6330c8b3861b60ce3aa039256e820cd5e76fd6ae7367642e2324`。发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2。

## 显示边界补充

显示预览现在与 HLG 一样拒绝没有显示峰值、OOTF 和参考白参数的 PQ 输出，不会把 PQ 数值直接按 sRGB 屏幕显示。先失败后通过的 `PreviewContractsTests` 均为 1 项：失败日志 `/tmp/lutcalc-pq-preview-red.log`，SHA-256 `792977c55d81e4260120b634b47a65720c31bd5f7992b61f1910438bcad715cb`；通过日志 `/tmp/lutcalc-pq-preview-green.log`，SHA-256 `1fc9c0a536d18b6cee183ea7fd5a647394394c4beaa3be96c0e348d8fc3622a8`。
