# Legacy cubic 判别式溢出验收

## 范围

本记录只覆盖 `LegacyCubicCurve1D` 反求分析中的导数临界点判定。它不扩大任意三维 LUT 的反求承诺，也不改变已有求根阈值、采样公式或网格规则。

## 失败契约

使用三个仍可表示为有限 `Double` 的样本：

```text
[8.984900966844184e258, 1.3457406847046075e265, -3.225797001415437e282]
```

该曲线的第一段导数系数仍为有限值，但直接计算 `qb * qb - 4 * qa * qc` 会溢出为 `infinity`。按缩放后的同一二次方程，段内存在有限临界点 `t = 2/3`。失败契约要求反求不能因为未缩放判别式溢出而静默丢弃该临界点。

## 修复

仅在原始判别式非有限时，以 `max(abs(a), abs(b), abs(c))` 缩放导数二次方程，再计算判别式和根；有限判别式路径保持原计算。系数仍要求有限，缩放失败仍返回无临界点，避免引入非有限结果。

## 实际验证

工具链：SwiftPM Release，Apple Swift XCTest。

```text
cd Native/Packages/LUTKit
swift test -c release --filter RootContractsTests/testLegacyCubicKeepsFiniteCriticalPointWhenDiscriminantOverflows
swift test -c release --filter RootContractsTests
```

结果：定向契约 1 项通过；`RootContractsTests` 全部 8 项通过。既有 Brent、二分、平坦段、非有限输入、单调 cubic 和多根契约均保持通过。

## 未覆盖范围

- 任意三维 cubic 全局根完备性仍未证明。
- 本记录未验证超大输入的最终采样精度，只验证临界点不会因判别式中间溢出被丢弃。
- 未改变 `SolveTolerance` 或生产采样器的阈值。
