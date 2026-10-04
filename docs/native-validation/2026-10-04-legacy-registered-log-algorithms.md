# Bolex、Panalog、DJI X5/X7/X9 DLog legacy 算法验收

日期：2026-10-04

## 范围

本包闭合旧 `js/gamma.js` 中三个已有 `LUTGammaLog` 注册项：`Bolex Log`、`Panalog`、`DJI X5/X7/X9 DLog`。三条曲线各自保留九参数、legacy-grey `0.2` 域和稳定 `TransferID`；没有把旧注册表的色域字符串解释成完整公开相机模型。

## 结果

- 旧 JavaScript 直接执行参照由 `tools/native-validation/generate-legacy-registered-log-reference.js` 生成，源码 SHA-256 为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`。
- `LegacyRegisteredLogContractsTests` 3 项通过，覆盖逐点参照、非有限输入、计划一次性缩放和目录身份。
- `LUTCatalogChecks` 通过：72 曲线、20 色域、68 预设、66 相机。
- Swift Release 全量实际执行 720 项，0 失败；LUTFormats 的 2 个既有外部夹具按原设计跳过。
- 三条曲线各生成 17³、33³、65³ CUBE，并由独立 90 位 Decimal 逐节点读回，阈值 `3e-15` 内全部通过：
  - Bolex 最大 `1.7010334240006141e-16`；
  - Panalog 最大 `1.6428813051717694e-16`；
  - DJI X5/X7/X9 最大 `1.3276478338655292e-16`。
- macOS、generic iOS、generic iOS Simulator Release 构建通过；163 个 Swift 源文件静态审计和三个 App 包资源审计通过。

命令、参照、CUBE、verifier 输出、全量测试和审计结果保存在[结果包](artifacts/2026-10-04-legacy-registered-log-contracts/)。

## 未覆盖

本包只关闭三条一维 legacy 解析和同空间曝光预设；Bolex、Panalog、DJI 的完整公开色域/相机模型、DJI DLog-M 查表、其他查表注册项、`.labin`、HDR/OOTF、ICC、LUTAnalyst、格式互操作、真机性能和发布验收仍未完成。Goal 保持 active。
