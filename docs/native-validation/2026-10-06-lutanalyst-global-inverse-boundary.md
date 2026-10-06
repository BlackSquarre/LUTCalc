# LUTAnalyst 全局逆边界审计

## 范围

本轮只审计 LUTAnalyst 的三线性、legacy tricubic 和组合 shaper/colour 逆解，
不扩展 UI、任务调度或发布范围。审计目标是区分已有数学完备子集与仍需研究的
全根证明，避免把有限 Newton 种子结果误报为全局结论。

## 已闭合子集

- 三线性严格仿射单元的四个混合项必须逐项严格为零；此时使用 3x3 矩阵反解，
  对可逆矩阵可证明单元内唯一解或无解，奇异矩阵保持 unresolved。
- 三线性所有网格单元都会枚举，目标不在任一输出包围盒时可证明无解；跨共享面
  的同一根会去重。非仿射单元即使 Newton 找到并经生产 sampler 回放，也保持
  unresolved。
- tricubic 所有 `(size - 1)^3` 单元都会枚举，Bernstein 输出包围盒不包含目标时
  可证明该单元无根；候选单元的 Newton 根只作为诊断，仍保持 unresolved。
- 组合 shaper/colour 只有颜色逆和每个 shaper 通道逆都没有 unresolved 时，
  才允许报告全局完备；折叠 shaper 或 tricubic 候选会继续传播 unresolved。

## 未闭合原因

任意含混合项三线性单元和 tricubic 单元可能存在多个根、切触根或奇异根。有限
Newton 初值集合不能证明没有遗漏；tricubic 还需要区间导数界、区间根隔离（例如
Krawczyk 或 Poincare-Miranda 细分）和共享面去重的完整证明。当前没有在缺少这些
不变量时猜测实现，也没有扩大 `isGloballyComplete` 的含义。

## 实际验证

工具链：Apple SwiftPM／XCTest，macOS 当前 Swift toolchain。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'TricubicInverseContractsTests|TrilinearInverseContractsTests|CombinedShaperColourInverseContractsTests|ImportedLUTAnalysisContractsTests'
```

结果：组合 7 项、Imported 19 项、tricubic 12 项、trilinear 14 项，共 52 项，
0 失败，退出码 `0`。完整日志：
`docs/native-validation/artifacts/2026-10-06-lutanalyst-global-inverse-boundary-release.log`。

日志 SHA-256：
`94b35f47571e7ab19db0a0cbb263af2ad5fc3815d0f4e7f405ec8a61078283f0`。

本记录不声称任意 3D LUT 全根证明已经完成；Goal 继续 `active`。
