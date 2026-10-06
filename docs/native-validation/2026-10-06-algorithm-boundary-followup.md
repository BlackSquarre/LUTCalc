# 算法边界并行复核记录

日期：2026-10-06。

## 范围

本轮只复核 `LUTCore`、`LUTAnalysis` 与既有 ICC 数学执行器中尚未闭合的公开数值和结构边界。复核重点为矩阵求逆与条件数、CIELAB 距离和编解码、HLG/PQ/OOTF 域边界、RootSolver 失败状态、遗留 cubic 导数临界点，以及 ICC mft/mAB/mBA 已接线子集。没有引入新的 transfer 身份、厂商采样表、降低网格或放宽阈值。

## 结果

当前实现已经对有限性、奇异／病态矩阵、残差、非括区间、非唯一根、取消、非有限函数值、峰值裁切反求和 OOTF 黑位／单位边界给出明确契约。遗留 cubic 导数判别式的有限系数溢出已有缩放求根路径；未发现仍可由公开公式和独立参照安全闭合的孤立缺口。

旧 PQ OOTF 的 `Lw`、`scale`、输入百分比和 knee 语义仍不能唯一对应 BT.2100 标准路由；完整任意三维全局反求、`.labin`、直接查表、完整 ICC/HDR/EDR/OOTF 仍属于未完成范围，不能借本次边界复核关闭。

## 实际验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'NumericContractsTests|ChromaticAdaptationContractsTests|CIELABContractsTests|HLGOOTFContractsTests|RootContractsTests'
```

工具链：SwiftPM Release，Apple Swift 工具链。结果：LUTCore 37 项、LUTAnalysis RootSolver 8 项，合计 45 项，0 失败，退出码 `0`。覆盖明细：CIELAB 8 项、CAT 2 项、HLG/OOTF 12 项、Numeric 15 项、RootSolver 8 项。

## 未覆盖范围

本记录不证明完整 ICC、目标软件往返、HDR/EDR 设备语义、任意 3D LUT 全局根完备性、`.labin` 与直接查表替代、UI、真机性能、签名发布或真实 `full-scope-acceptance.json`。Goal 保持 `active`。
