# tricubic Bernstein 系数审计接口

## 变更

`LegacyTricubicVolume3D` 新增 `cellBernsteinCoefficients(_:)`，运行时把现有 Catmull-Rom 生产 sampler 的一个单元转换为 64 个张量积 Bernstein 系数。`cellOutputBounds(_:)` 改为复用该接口，避免包围盒和后续区间分析各自实现一套多项式转换。

该接口返回的是由用户/运行时 LUT 网格即时推导的诊断数据，不是 App 内置采样资源，也没有改变网格、ghost-node 规则、插值或阈值。

## 契约与结果

新增三个边界组：`testCellBernsteinCoefficientsReconstructProductionSamplerAndEncloseCell` 在非线性 5³ 网格上检查 64 系数、5×5×5 单元内节点重建与生产 sampler 的差异不超过 `2e-12`；`testCellBernsteinCoefficientsMatchIndependentAffineReference` 用解析仿射场直接核对全部 64 个控制点；非法空/短坐标、负索引和越界单元均明确返回 `.outsideDomain`。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter LegacyTricubicContractsTests
```

结果：`6/6` 通过，失败 `0`。日志 SHA-256：
`0e0f3b2d9eeb0f861e51e22fb4480bad6a32239f441ded8e4a4453b0eb515e13`。

## 未完成范围

该接口只是后续区间细分所需的可复核数据面，不证明 tricubic 任意单元全根隔离、奇异集合、共享面去重或任意 3D 全局完备性。相关范围继续返回 `unresolved`，Goal 保持 `active`。
