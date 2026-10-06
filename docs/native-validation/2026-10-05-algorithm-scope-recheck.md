# 算法范围复核与局部反求回归记录

日期：2026-10-05。

本次只复核算法范围，不扩充 UI、平台交互或真机性能范围。检查了 `docs/colour-research-2026-09-23.md`、查表替代台账、最新算法闭合审计和现有 `LUTCore`／`LUTAnalysis` 实现。公开资料中没有新增同时满足连续公式、适用范围、独立参照和无需采样表四项条件的内置变换，因此没有新增厂商算法身份，也没有把旧 `.labin` 或 spline 节点改写为 Swift 常量。

## 回归命令

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'TrilinearInverseContractsTests|TetrahedralInverseContractsTests|TricubicInverseContractsTests|CombinedShaperColourInverseContractsTests|NumericContractsTests'
git diff --check
```

结果：算法定向测试 31 项通过，`NumericContractsTests` 15 项通过，退出码 `0`；`git diff --check` 通过。定向测试覆盖三线性、四面体、旧 tricubic、组合 shaper 局部反求和核心 Double 网格/矩阵边界。

## 未闭合范围

- 任意 3D LUT 的连续域全根完备性、跨单元多根、切向根和唯一性仍无证明；现有诊断继续对有限种子遗漏和病态单元报告 `unresolved`。
- 自动 transfer/colour 分离、完整 LUT 重建、生成计划和导出接线仍未完成。
- 查表替代台账仍为 `.labin` `0/9`、直接查表注册 `0/45`。
- DJI DLog-M、Canon CP IDT、RED DRAGONColor2/IPP2、SUP2 raw、连续 EI/高 EI shoulder、Planck/Duv/Dpl/PSST 和完整 PQ/HDR/ICC 仍按资料或语义阻塞处理。

本记录不改变 `FULL-05`、`H10` 或 Goal 的 active 状态。
