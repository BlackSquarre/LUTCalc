# LUTAnalyst 旧 tricubic 局部反求诊断验收

日期：2026-10-05

## 范围

本轮只闭合旧 `LegacyTricubicVolume3D` 生产 sampler 的局部反求诊断子集。旧 sampler 的 ghost-node、R-fast 网格、Catmull-Rom 权重和域外 `reject`／`clampToDomain` 语义保持不变。实现没有降低 LUT 网格、位宽、插值规则或既有 `2e-12` 相对尺度阈值。

新增内容：

- `LegacyTricubicVolume3D.sampleWithJacobian`：采样值和输入空间解析 Jacobian 使用同一 cell 与 ghost-node 数据。
- `LegacyTricubicVolume3D.cellOutputBounds`：把四阶 cardinal 权重转换成 Bernstein 基，使用 64 个 Bernstein 系数包围整个 cubic 单元，包含节点间 overshoot。
- `Tricubic3DInverse`：按包围盒命中的单元运行有限 Newton 候选；候选必须再次通过生产 sampler 回放，残差超过阈值或矩阵奇异时不接受。
- `ImportedLUTAnalyzer.diagnoseTricubicColourInverse`：只提供显式诊断入口；带 shaper、其他插值或不满足 3D LUT 条件时拒绝。

`unresolved` 表示包围盒允许目标但有限候选没有证明根，不能解释成 `noSolution`。这保留了资料和多解不确定性，不把数值猜测接入生成路径。

## 契约

`TricubicInverseContractsTests` 共 8 项：

1. 恒等网格根经过生产 sampler 回放。
2. 折叠 cubic 映射保留两个分支，不选择单一根。
3. Bernstein 包围盒外的目标报告无解。
4. 奇异映射报告未决，而不是伪造唯一根。
5. 非单位输入域的根回到原始域坐标。
6. 有限差分独立核对解析 Jacobian。
7. Bernstein 包围盒包含生产 sampler 的 overshoot。
8. 非有限 tolerance、零资源上限和 shaper LUT 明确拒绝。

## 实际命令与结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter TricubicInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter TricubicInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release
bash Scripts/verify-native-numerics.sh
```

- 定向 Debug：8 项通过，退出码 `0`。
- 定向 Release：8 项通过，退出码 `0`。
- Swift Release 全量：退出码 `0`，包含 `LUTAnalysisTests` 74 项、0 失败；其余测试包也无失败。既有外部夹具仍按项目原规则处理。
- 原生数值门禁：退出码 `0`；54 个 CUBE 生成／读回案例和既有数值检查全部通过。

结果包：`docs/native-validation/artifacts/2026-10-05-lutanalyst-tricubic-inverse/`。

SHA-256：

- `targeted-debug.log`: `266c78f739cf8f291cef94fa1dfcaa95216f27a0286b3978f123e7f27677de07`
- `targeted-release.log`: `7d7382db2409c8c0afe0c6a14d5f6ac3e95662325f6e5f12a729194652550d21`
- `full-release.log`: `d4ecb69092e48b4af0d24cffaef4c213086f5174519b41c89aa1933ae378f31b`
- `numerics-gate.log`: `b609a6e1e79c5018164f0e53e6c3cb8409b85edd36b507c7505188a698aa71b8`
- 四个 `.exit` 文件内容均为 `0`，SHA-256 为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`。

## 未覆盖范围

- 有限 Newton 种子不构成任意连续 cubic 域的全根证明；跨单元多根、切向根、病态 Jacobian 和根遗漏仍可能报告 `unresolved`。
- 没有把该诊断接入 `inverseColourLUT` 的默认路径、批次生成、项目持久化或 UI，也没有实现组合 shaper 与三维 colour 的完整反接线。
- 不关闭任意 3D LUT 全局反求、自动 transfer/colour 分离、完整 LUTAnalyst、`.labin` `0/9`、直接查表注册 `0/45`、完整 HDR/ICC、目标软件往返、平台性能或发布验收。FULL-05、H10 和 Goal 保持 `active`。
