# LUTAnalyst combined shaper 反求边界验收

## 范围

本项审计 `ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse` 的取消传播、`maxSolutions` 上限和重复根去重。目标是保证上限只统计最终回放确认且坐标去重后的根，并保证长时间组合枚举可以响应 Swift 任务取消。

## 先行契约与修复

先行静态审计发现组合候选循环没有在 shaper 根组合和颜色回放之间检查取消；同时上限检查位于去重判断之前，可能让重复候选消耗上限。生产代码随后在颜色解、三通道根和组合循环加入 `Task.checkCancellation()`，并将 `maxSolutions` 检查移到最终坐标去重之后。

新增契约 `testMaxSolutionsCountsDistinctRootsAfterBoundaryDeduplication` 使用 3x3 identity colour/shaper LUT，目标位于共享 cell 面 `(0.5, 0.25, 0.75)`，`maxSolutions=1` 必须得到唯一根；原有 folded shaper 双根契约仍要求 `maxSolutions=1` 返回 `.invalidInverseLimit`。

## 实际命令与结果

工具链：Xcode SwiftPM，macOS arm64，Swift 6。

```sh
swift test --package-path Native/Packages/LUTKit --filter CombinedShaperColourInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter CombinedShaperColourInverseContractsTests
git diff --check
```

Debug 和 Release 均执行 7 项，0 失败；其中取消传播、identity 单根、folded 双根、共享面重复根及上限错误分类契约全部通过。`git diff --check` 通过。

## 未覆盖范围

本项只闭合 combined shaper 的取消检查和 distinct-root 上限语义，不声明任意三维 LUT 全局反求、全根完备性、`.labin` 或直接查表替代、完整 ICC/HDR/OOTF、目标软件往返、平台验收或发布清单完成。Goal 继续保持 `active`。
