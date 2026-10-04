# LUTAnalyst 1D 逐通道反求诊断验收

## 范围

本包处理已有 LUTAnalyst 原生范围中的 1D transfer 和组合 shaper 反求诊断。没有实现任意三维 LUT 反求，没有推断视觉上近似仿射的模型，也没有改变既有 `inverseTransfer` 或 `inverseShaper` 的错误语义。

## 契约先行

先在旧实现上新增 transfer 逐通道契约和 shaper 逐通道契约。旧实现没有 `diagnoseTransferInverse` 或 `diagnoseShaperInverse`，因此定向 Release 编译真实失败；transfer 红灯日志 `/tmp/lutcalc-shaper-diagnostic-red-20261004.log`，SHA-256 `b25ff60731ba57f7323fc3aca66bac7af0ac6d594ea6fa6d206f70ee7dc5a4c0`，错误为 `ImportedLUTAnalyzer` 缺少诊断成员。

## 实现

新增：

- `TransferInverseChannelDiagnostic`：保存 `SolveStatus`、值、残差、括区间、迭代次数和求值次数。
- `TransferInverseDiagnostic`：保存插值策略和三个通道诊断。
- `ImportedLUTAnalyzer.diagnoseTransferInverse(...)`：只分析 transfer LUT；线性路径使用 `MonotonicCurve1D`，`tricubicLegacyV1` 使用既有 `LegacyCubicCurve1D.inverse`。
- `ImportedLUTAnalyzer.diagnoseShaperInverse(...)`：只分析组合 LUT 的独立 shaper，复用相同的逐通道诊断结构，不穿越三维 colour LUT。

非唯一目标的括区间保留实际平段，例如本次契约中的 `0.5...1.0`；域外目标返回 `.notBracketed`，不伪造候选值。非有限 RGB 输出按三个通道返回 `.nonFinite`。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testTransferInverseDiagnostic' \
  2>&1 | tee /tmp/lutcalc-lutanalyst-diagnostics-contract-20261004-r2.log
```

结果：退出码 `0`，2 项通过；日志 SHA-256：
`5fea76bf5759a326110c19b5387e34ba7173d2dc992c4426e242a03b1fe2e58f`。

shaper 定向契约：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testShaperInverseDiagnostic' \
  2>&1 | tee /tmp/lutcalc-shaper-diagnostic-contract-20261004.log
```

结果：退出码 `0`，1 项通过；日志 SHA-256：
`eb57fba06d4917a496a3463d5405b63e0f1cc13ee83579378b45490f429cce81`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lutanalyst-shaper-diagnostics-full-release-20261004.log 2>&1
```

结果：退出码 `0`；8 个 Swift 测试包共执行 `736` 项，失败 `0`，其中 LUTFormats 的既有外部夹具 `2` 项按原规则跳过；日志 SHA-256：
`3e9956ca074a20c875d68ebb5f2d5553cff2c9baa5ed70133ec2bc26e9a9044b`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`：`1afa2b13249d7c4c95dd398c8bb38a322e6d7c2dc57a98d9fca82e5a436f9a2a`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`：`5d6bad54f0884585391ccb71d31ead0349788e98a15ba349ab621e79b4662928`

## 未覆盖范围

完整 LUTAnalyst 的 TF／颜色分离重建、方向和量化元数据、病态模型报告、生成计划／项目／导出接入、任意三维逆、三维域外旧实现冲突仍未完成。直接查表、`.labin`、Canon CP IDT、RED DRAGONColor2／IPP2、SUP2 raw、PQ OOTF、完整 HDR／ICC 也没有因本包改变状态。UI、iPad 验收、追加真机性能和发布清单继续按用户决定暂缓。
