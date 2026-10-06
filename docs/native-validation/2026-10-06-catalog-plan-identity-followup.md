# AlgorithmCatalog 与 TransformPlan 身份复核补充

## 范围

本轮复核内置 `AlgorithmCatalog` 的 transfer、色域和预设引用，以及 `TransformPlan.basePlanVersion` 的条件顺序和缓存身份。重点检查不同 `ColorSpaceID`、不同预设参数或不同 transfer ID 是否可能产生相同计划身份。

## 契约先行发现

新增目录契约枚举所有内置预设，按 `TransformPlan.planVersion` 分组；同一身份只有在完整 `TransformSettings` 完全相等时才允许重复。该契约首先发现两个问题：

1. `sony.slog3-to-linear-ap0.v1` 与 `sony.slog3-sgamut3-to-linear-ap0.v1` 的输入色域不同，但旧身份只包含 transfer ID，未包含 `ColorSpaceID`。
2. `bbc.whp283-400-exposure-one.v1` 与 `bbc.whp283-800-exposure-one.v1` 的 transfer ID 不同，但旧 BBC WHP283 分支使用同一固定身份。

## 修复

- S-Log3 计划身份现在包含输入 transfer、输出 transfer、输入色域和输出色域。
- BBC WHP283 计划身份现在包含输入 transfer 和输出 transfer。
- 没有改变转换公式、网格、位宽、插值或阈值，也没有加入采样表。

## 实际验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter RegistryContractsTests/testBuiltInPresetPlanIdentitiesDoNotAliasDifferentSettings
swift test --package-path Native/Packages/LUTKit -c release --filter TransformAlgorithmWiringContractsTests/testSLog3PlansIncludeBothPublishedGamutIdentities
git diff --check
```

结果：目录去别名契约 `1/1` 通过，S-Log3 色域身份契约 `1/1` 通过，构建成功，`git diff --check` 通过。

## 未覆盖范围

本记录只关闭计划身份碰撞的两个已证实子集，不代表任意 3D LUT 全局反求、`.labin`、直接查表、完整 ICC/HDR 或平台发布验收完成。Goal 继续保持 `active`。
