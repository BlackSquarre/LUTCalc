# CIELAB 与色貌算法缺口审计

## 审计范围

本轮检查现有 `LUTCore` 的 CIELAB/XYZ 计划、ICC PCS Lab 编解码、白点适应和
公开 CAT。DeltaE 与 CAT 本身不新增算法，只作为已有实现的回归边界。搜索了
`CIELAB`、`CIECAM02/CAM16`、`Oklab/Oklch`、`JzAzBz`、`ICtCp`、`Luv` 和
`Hunter Lab` 的源代码、目录与测试。

## 已有覆盖

- CIE 1976 Lab 分段函数（`epsilon` 分支）、D50/D65 白点、扩展 XYZ 域和往返；
- CIELABTransformPlan 的显式白点、CAT 阶段、有限值拒绝和 33/65 网格往返；
- CIE CAT02、CAT97s、Bradford、von Kries、Sharp、CMCCAT2000、Bianco BS/BSPC、
  XYZ scaling 的独立锥响应矩阵参照；
- ICC 8 位/16 位/连续/float PCS Lab 编解码及其范围、量化和非有限值契约。

## 实际验证

```text
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'CIELABContractsTests|CIELABPlanContractsTests|ChromaticAdaptationContractsTests'
```

结果：LUTCore `15/15`，失败 `0`，退出码 `0`；日志 SHA-256：
`608b34f13c88cee0a70542125209ed47393435d7733a54e80faac55db7ac97c5`。

```text
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ICCLabPCSContractsTests
```

结果：LUTPreview `4/4`，失败 `0`，退出码 `0`；日志 SHA-256：
`af71b0bc6927b226313ea1405a570f54cc37f226f1ca51313ada83ff5950c0e9`。

## 未闭合项与结论

当前没有 `CIECAM02/CAM16`、Oklab/Oklch、Jzazbz、ICtCp、Luv 或 Hunter Lab 的
生产类型、目录身份和独立参照。色貌模型还需要适应场景、背景、周围亮度、白点和
显示峰值等参数；仅加入一个无参数公式会改变语义，不能由现有 Lab/CAT 类型推导。
Oklab/Oklch 在覆盖文档中仅列为低优先级 grading space，也没有本项目所需的捕获
或显示 transfer 契约。

因此本轮没有安全新增算法，也没有生产代码修改；不把 CIELAB 或 CAT 回归通过
误报为完整色貌覆盖。该研究缺口继续保持，Goal 仍为 `active`。
