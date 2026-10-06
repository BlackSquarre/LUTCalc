# 三线性与四面体反求取消语义验收

## 范围

本验收只覆盖 `Trilinear3DInverse.analyze` 与 `Tetrahedral3DInverse.analyze` 的 Swift 任务取消边界。它不声称任意三维 LUT 的全局反求、全根完备性或多解证明已经完成。

## 契约先行

先在两个契约测试中加入已取消任务调用。实现前，两个 API 都会继续扫描并返回报告，导致取消契约失败：

```text
TrilinearInverseContractsTests.testCancellationIsPropagatedBeforeScanningBoxes: failed
TetrahedralInverseContractsTests.testCancellationIsPropagatedBeforeScanningTetrahedra: failed
```

## 实现

在两个入口、各层网格扫描循环和四面体遍历循环加入 `try Task.checkCancellation()`。API 保持同步 `throws`，由调用方的 Swift `Task` 传播标准 `CancellationError`；没有返回部分解或伪造 `unresolved` 报告。

## 实际验证

工具链：SwiftPM，Swift 6 工具链，macOS 主机。

Debug 命令：

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter 'TrilinearInverseContractsTests/testCancellationIsPropagatedBeforeScanningBoxes|TetrahedralInverseContractsTests/testCancellationIsPropagatedBeforeScanningTetrahedra'
```

结果：2 项通过，0 失败。

Release 命令：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter 'TrilinearInverseContractsTests|TetrahedralInverseContractsTests'
```

结果：23 项通过，0 失败；其中三线性 12 项、四面体 11 项。

## 未覆盖范围

本项没有关闭任意三维 LUT 全局反求、全根完备性、自动 transfer/colour 分离、`.labin` 替代、直接查表替代或 LUTAnalyst 全功能。取消后的后台恢复、平台 UI 和发布验收仍待处理。
