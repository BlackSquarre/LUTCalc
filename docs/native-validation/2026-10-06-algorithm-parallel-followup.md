# 并行算法工作包后续验收

## 四面体严格仿射判定

四面体插值单元本身是严格仿射映射；现有实现已有矩阵求解、重心坐标检查和生产 sampler 回放。本轮新增目标位于输出包围盒内、但精确逆坐标落在单纯形外的失败契约，要求返回 `noSolution`、无解且无未决单元。

Release `TetrahedralInverseContractsTests` 10 项通过，日志 SHA-256：`2b6f832ef30feab2ccd61c475b55c1191300aca54bb18bad2d1cc1cd8039670a`。

这只强化单元级仿射边界，不证明任意 LUT 的全局根完备性、多根覆盖或连续域唯一性。

## PQ OOTF 研究复核

独立 80 位 Decimal 探针和 Swift Release 契约重跑通过。旧公式在 knee 两侧输出仍有约 `1.7751367975487e-3` nits 跳变；旧 `Lw/scale`、输入百分比单位、knee/2.4 与 BT.2100 scene-to-display OOTF 没有公开一一对应关系。

因此不猜公式、不平滑历史跳变、不接入 `TransformPlan`。标准 `PQTransfer` 与隔离的 `LegacyPQOOTF` 保持现状，PQ OOTF、完整 HDR/EDR 和自动峰值继续研究阻塞。

详细记录：[PQ OOTF 研究复核](2026-10-05-pq-ootf-research-followup.md)。

## 1D cubic 边界审计

审计发现 `LegacyCubicCurve1D` 的导数临界点判别式在极大但有限系数下可能溢出为无穷并被当成“没有临界点”。本轮未猜测稳定求根修复，也未把该风险标为已完成；需要下一工作包先构造独立有限系数契约，再采用缩放二次方程判别式并验证单值性结果。

## 未覆盖范围

上述结果不关闭任意 3D LUT 全局反求、自动 transfer/colour 分离、完整重建、`.labin` `0/9`、直接查表 `0/45`、完整 ICC/HDR、厂商资料阻塞、平台交互或发布验收。Goal 继续 `active`。
