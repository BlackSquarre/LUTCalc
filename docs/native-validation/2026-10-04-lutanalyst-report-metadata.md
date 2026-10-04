# LUTAnalyst 分析报告元数据接入验收

## 范围

本包把已经结构化的 `.lacube/.labin` 区段语义接入 `ImportedLUTAnalysisReport`：报告分别保留 transfer 和 colour metadata，并携带文件量化语义。它不改变 LUT 样本、插值、网格、Double 生成路径或任意 3D 逆的拒绝边界。

## 契约先行

先在旧实现上加入报告层契约：检查 transfer/colour 区段不混淆、`.lacube` 量化身份为 textual Double，并要求倒置边界在产生报告前失败。旧实现没有 `metadata` 字段和 `.invalidMetadata` 错误，定向 Release 编译真实失败。红灯日志：`/tmp/lutcalc-lutanalyst-report-metadata-red-20261004.log`；SHA-256：`a12f5bde181b5321f0d7d3de7586dbfe1c4c053a6849ef348ebfb13b0269c505`。

## 实现

- 新增 `ImportedLUTMetadataAnalysis`，分别保存 transfer 语义、可选 colour 语义和 `LUTAnalysisQuantizationSemantics`。
- `ImportedLUTAnalyzer.analyze` 在存在分析文件时调用两段 `semantics()`；缺少边界、非有限边界、倒置或相等边界通过 `.invalidMetadata` 明确返回。
- 直接分析普通 `CubeLUT` 时 metadata 保持 `nil`，不虚构文件来源。
- 任意三维颜色 LUT 仍要求调用方提供显式模型；无模型入口继续返回 `.arbitrary3DInverseUnsupported`。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testAnalysis' \
  > /tmp/lutcalc-lutanalyst-report-metadata-contract-20261004.log 2>&1
```

结果：退出码 `0`，2 项通过；日志 SHA-256：
`600f9f6998a6e85d22d4308384f60c03147ed148884e93f34bea5225bbd4dcd2`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lutanalyst-report-metadata-full-release-20261004.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `742` 项，失败 `0`。LUTSharedUI `162`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `60`（其中 2 项既有外部夹具跳过）、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `37`。完整日志 SHA-256：
`9939b92e6aca8ec3823eff717111fd7ee95ed2cac15be3d40dec7af19ca75f5b`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`：`abc414e11c15b92051bd857b8fb00f37fa4aa78e9e499c9cc408a6b083aaaf8c`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`：`62726556d83a58702be890bd237aad06ed536611765a821cdc1aa4374eb33c74`

## 未覆盖范围

本包只闭合报告层 metadata 传播。完整 TF／颜色分离与重建、方向和量化接入生成／项目／导出、病态／多解全局报告、任意 3D 逆、目标软件往返、9 个 `.labin` 资源及 45 个直接查表注册仍未完成；UI、设备、提供商、发布和真实全量清单状态不变，Goal 保持 active。
