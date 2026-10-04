# 2026-10-04 LUTAnalyst 一维 cubic 全局多根诊断验收

## 范围

本包只处理用户导入 LUT 中独立一维 transfer 通道的 cubic 全域多根诊断。它不反求任意三维 colour LUT，不从采样节点自动推断 transfer／colour 分离，也不把多根曲线压成单一结果。原有严格单值 `inverse` 行为保持不变：非单值曲线继续拒绝生成严格反求计划。

## 契约先行

先在旧实现上增加非单调 cubic 三通道多根和域外结果契约，确认新增入口尚不存在并产生编译失败；随后实现 `LegacyCubicCurve1D.allInverseRoots` 与 `ImportedLUTAnalyzer.diagnoseTransferInverseRoots`。契约要求保留每个通道的状态、全部候选根、括区间、残差和求值次数。

## 实现与数值边界

- 每个 cubic segment 按导数临界点切分为单调区间，再用现有 `RootSolver.brent` 搜索符号变化区间。
- 端点根单独记录；相邻区间重复根按当前 `SolveTolerance` 去重；结果按输入域升序排列。
- 多根通道返回 `.nonUnique`，但不丢弃根；无根域外结果返回 `.notBracketed`，非法或非有限输入保持显式失败状态。
- 计算全程使用 Swift `Double`。本包不改变插值、网格、位宽或既有误差阈值。

## 验证命令与结果

定向 Debug：

```sh
swift test --package-path Native/Packages/LUTKit --filter ImportedLUTAnalysisContractsTests
```

结果为 18 项通过、0 失败；日志：`/tmp/lutcalc-lutanalyst-global-roots-debug-20261004-r3.log`；SHA-256：`207fe8e8959292d7814d3d2fd218f335daf69dd84cecb5e0870eb6128bd783b5`。

定向 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter ImportedLUTAnalysisContractsTests
```

结果为 18 项通过、0 失败；日志：`/tmp/lutcalc-lutanalyst-global-roots-release-20261004.log`；SHA-256：`f3e830f0d2e087e96e6babcd0389a56bd0b7089149b1caaea53873522b4252b8`。

当前工作区复验使用相同 Release 命令，退出码为 `0`，18 项通过、0 失败；日志：`/tmp/lutcalc-lutanalyst-global-roots-release-final-20261004.log`；SHA-256：`21606e1dd42f40501dec0e4396412b47dc502a4f02e5fcc3d684e0a22fa36efe`。

全量 Swift Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果为 8 个测试包全部通过、0 失败；LUTFormats 的 2 项既有外部夹具按原规则跳过。新增后的 `LUTAnalysisTests.xctest` 为 45 项、0 失败；总日志：`/tmp/lutcalc-lutanalyst-global-roots-full-release-20261004.log`；SHA-256：`be34200f0fe1f4145456daba85b44e9feac5c5040eee207cf48d6fd413f1efa8`。

## 独立结果

三通道 hump cubic 目标值 `0.5` 均找到 2 个根，R 通道根为 `0.12732200375003508` 和 `0.8182043533932605`；G/B 通道相同。全部根的绝对函数残差不超过 `2e-12`。该数值仅证明当前 cubic 分段和求根实现能够完整报告这个多解示例，不证明任意采样 LUT 存在唯一连续模型。

源码与契约哈希：

```text
511e73b328454ab32095d72826a1d84d83fe04846f431f3546933199ac9577e4  Native/Packages/LUTKit/Sources/LUTAnalysis/LegacyCubicCurveAnalysis.swift
58b90ba9a6cc3c26f7b8dd1514f235dd0a546b7e1a0bfdc62284ebb756e6b594  Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift
1022eca30e33622ecc0b9ffed07153a8fbb915084db4718167d3243b238cabac  Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift
```

## 未覆盖范围

任意三维 LUT 逆、自动 transfer／colour 分离、完整重建、方向／量化到全部导出格式的接入、全局三维多解证明、厂商 LUT／`.labin` 替代和目标调色软件往返仍未完成。本包不勾选 H07、H10、H14 或 FULL-05，Goal 继续保持 `active`。
