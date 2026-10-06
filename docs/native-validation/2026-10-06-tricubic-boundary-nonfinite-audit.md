# Tricubic 反求边界根与非有限分支审计

## 范围

本记录只审计 `Tricubic3DInverse` 的两个结构边界：精确落在相邻 cell 共享面的根，以及目标值的非有限输入分类。它不宣称任意三维 LUT 的全局反求完备性。

## 精确共享面根

新增契约 `testExactCellBoundaryRootIsDeduplicatedAcrossAdjacentCells` 使用 4 阶身份网格，目标输入为 `(1/3, 0.37, 0.63)`，其中 R 坐标精确位于前两个 cell 的共享面。生产 tricubic sampler 回放后，Debug 与 Release 均得到：

- `status = unique`
- `solutions.count = 1`
- 三个输入坐标误差不超过 `2e-12`
- `unresolvedCellCount = 0`

这证明当前根去重按输入坐标保留单一根，并未把共享面边界误报为 unresolved。

## 非有限目标

`RGB64` 构造器要求三个通道均为有限 `Double`，NaN/Inf 在进入反求 API 前即以 `NumericError.nonFinite` 拒绝。因此 `Trilinear3DInverseReport`、`Tetrahedral3DInverseReport` 和 `Tricubic3DInverseReport` 中的 `.nonFinite` 分支是内部防御分类，当前公共 API 无法构造该报告。没有伪造不可达分支的测试，也没有放宽 `RGB64` 有限值不变量。

## 命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter TricubicInverseContractsTests.testExactCellBoundaryRootIsDeduplicatedAcrossAdjacentCells
通过，1 项，0 失败

swift test --package-path Native/Packages/LUTKit -c release --filter TricubicInverseContractsTests.testExactCellBoundaryRootIsDeduplicatedAcrossAdjacentCells
通过，1 项，0 失败

git diff --check
通过
```

另增域最大值边界契约：三线性、四面体和 tricubic 身份网格目标 `(1, 1, 1)` 均在 Debug/Release 通过，三者均报告单一根且 unresolved 计数为零。

## 未覆盖范围

任意三维 LUT 全局根完备性、所有多解的数学证明、`.labin` 与直接查表替代仍未完成；本记录不关闭这些范围。
