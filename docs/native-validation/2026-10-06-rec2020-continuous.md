# BT.2020 连续 OETF 原生算法验收

日期：2026-10-06

## 范围

本次关闭研究清单 S03 中“精确连续形式”与实用 10-bit 形式混用的缺口。新增 `rec2020.bt2020-continuous.v1`，使用 BT.2020-2 表 3 的连续参数 `alpha=1.09929682680944`、`beta=0.018053968510807`、低段斜率 `4.5`，以及对应逆变换。它与已有 `rec2020.bt2020-10bit.v1` 保持独立，运行时全部使用 Swift `Double`，不引入采样表。

## 契约与结果

先新增失败契约，验证连续 transfer、目录身份和独立预设不存在；实现后接入 `TransferID`、`TransformPlan`、`NativeOutputEncoder`、输出编码分类和 `AlgorithmCatalog`。

- Debug：`swift test --package-path Native/Packages/LUTKit -c debug --filter Rec2020ContinuousContractsTests`，2 项通过。
- Release：`swift test --package-path Native/Packages/LUTKit -c release --filter Rec2020ContinuousContractsTests`，2 项通过。
- Release 日志：`artifacts/2026-10-06-rec2020-continuous/release.log`。
- SHA-256：`50b7f6c7c7c904a7789f0b1fce32b907195b9e70eb7c2136f956e22fddb65e5d`。
- Release `LUTCatalogChecks` 在同步计数后通过：82 条曲线、23 个色域、76 个预设。
- `git diff --check`：通过。

契约覆盖连续分支端点、独立逆变换 round-trip、非有限输入拒绝、目录身份与实用 10-bit ID 分离；不覆盖完整 BT.2020 编码范围、显示链、HDR/EDR、第三方软件往返或设备预设。

## 未完成

BT.2020 的其他系统语义、完整 HDR/EDR/OOTF、`.labin` `0/9`、直接查表 `0/45`、任意三维全局反求和发布验收仍未完成。Goal 保持 `active`。
