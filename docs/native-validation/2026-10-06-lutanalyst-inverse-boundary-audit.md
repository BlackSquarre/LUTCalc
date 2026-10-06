# LUTAnalyst 反求残差与根分类审计

## 审计范围

复核 `ImportedLUTAnalyzer` 的 transfer 根诊断、shaper 根组合和三种 colour LUT 反求的残差门限、域边界、去重与状态传播。审计未扩大到任意三维 LUT 的全局反求证明。

## 已确认语义

- 一维 transfer 的 `diagnoseTransferInverseRoots` 保留每个 cubic segment 的全部可收敛根；恒定平台通过 `nonUniqueBrackets` 暴露区间，域外目标保持 `.notBracketed`。
- colour 反求的每个候选根都经过生产 sampler replay，并使用 `residual <= tolerance * max(1, |target channels|)` 接受；非有限残差不会进入结果。
- tri/tetra/tricubic 和 combined shaper colour 结果均按输入坐标去重、按 R/G/B 排序；边界根测试已覆盖共享 cell 面和域最大值。
- unresolved cell/channel 不会被降级为 `noSolution`；资料不足的全局根完备性保持显式未完成。

## 结论

本轮未发现同时具备明确公开语义、独立参照和最小修复边界的新生产缺口。非有限目标在公共 API 由 `RGB64` 有限值不变量提前拒绝；combined shaper 的 `.nonFinite` 同样是防御分支。没有猜测修改或放宽阈值。

新增取消契约 `testCancellationIsPropagatedBeforeComposition` 在 Debug/Release 均通过。combined shaper 组合调用下层 tri/tetra/tricubic 反求器的取消检查，已能传播 `CancellationError`；本轮未发现独立取消缺口。

新增 `testMaxSolutionsRejectsWhenDistinctBranchesExceedLimit`：folded shaper 的两个不同输入根在 `maxSolutions = 1` 时明确返回 `.invalidInverseLimit`，Debug/Release 均通过；不会静默截断多根结果。

代码审阅另外发现 `maxSolutions` 的检查位于 combined shaper 候选 replay 之前；该位置在达到上限时会提前拒绝后续候选，但当前公开构造器会先对 colour 根和 scalar 根去重，尚未形成可复现的重复候选失败契约。本轮不移动检查，也不把静态疑点报告为已修复。

## 未覆盖

任意 3D LUT 全局根完备性、自动 transfer/colour 分离、`.labin` 与直接查表替代仍未完成；本审计不关闭这些范围。
