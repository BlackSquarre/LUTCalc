# LUTAnalyst tricubic 单元枚举证据验收

## 范围

本项只补充 `Tricubic3DInverseReport` 的枚举证据：报告现在分别记录完整 `(size - 1)^3` 单元数和通过 Bernstein 输出包围盒筛选的候选单元数。该字段用于区分“目标落在所有单元包围盒之外”和“存在候选单元但仍需要区间根隔离”。不改变 Newton 种子、Double 精度、生产采样回放或残差阈值。

## 契约与结果

执行命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter TricubicInverseContractsTests
```

工具链：SwiftPM Release，当前工作区 Swift 工具链；未清理既有 `.build` 缓存。

结果：`TricubicInverseContractsTests` 共 12 项，失败 0。identity 4³ 网格报告 `enumeratedCellCount = 27` 且候选数大于 0；域外目标报告 `enumeratedCellCount = 27`、`candidateCellCount = 0`、`isGloballyComplete = true`。identity、折叠 cubic、共享面边界、奇异映射和有限 Newton 迭代耗尽仍保持 `unresolved`，没有被枚举计数误标为全局完备。

## 未覆盖范围

tricubic 任意候选单元的全根隔离、奇异集合处理和跨单元共享面去重仍未实现；有限 Newton 种子找到的根只作为诊断保留。因此本项不关闭任意三维 LUT 全局反求、多解完备证明、自动 transfer/colour 分离、完整重建或发布验收。
