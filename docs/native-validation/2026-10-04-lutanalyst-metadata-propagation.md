# LUTAnalyst 元数据到输入反求计划传播验收

## 范围

本包只闭合 LUTAnalyst 分析文件元数据进入严格 1D 输入反求计划的身份传播。计划现在保留 transfer／colour 语义和文件量化语义；项目重开时从已保存的 `.lacube`／`.labin` 重新读取分析文件并传入计划。该元数据只作为来源身份和恢复校验，不改变样本、Double 生成路径、网格、插值实现或任意 3D 逆拒绝边界。

## 契约先行与修复

新增契约覆盖：

- 计划读取并保留 transfer 元数据和 textual Double／legacy LABin 量化身份。
- 相同样本但不同 range、边界、插值或量化来源生成不同 `contentFingerprint`，避免批次报告和 durable checkpoint 混用。
- 倒置／非有限／缺失单侧边界在 cubic stencil 构造前返回 `.invalidMetadata`。
- 空的合成分析包装不携带实际来源身份，继续保持历史直接 LUT 指纹，兼容既有测试和调用方。
- 项目 `makeGenerationRequest` 不再丢弃重开用户 LUT 的 `analysis`，严格反求计划使用已保存文件的完整分析语义。

实现文件：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ExposureBatchInverseIdentityContractsTests|ImportedLUTAnalysisContractsTests/testInversePlan' \
  2>&1 | tee /tmp/lutcalc-lutanalyst-metadata-propagation-targeted-r2.log
```

结果：退出码 `0`；输入反求批次身份 3 项、分析计划 2 项均通过。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lutanalyst-metadata-propagation-full-release-r3.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `746` 项，失败 `0`。各包最终汇总为 LUTSharedUI `163`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `61`（其中 2 项既有外部夹具按原规则跳过）、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `39`；日志 SHA-256：`d146091d915de00ce90b480ead693bb81f70e24dc4f62a069762adacfd87f4ff`。

工具链：Swift `6.4`（swiftlang `6.4.0.34.1`），Xcode `27.0`（`27A266a`），macOS arm64 Release。

项目重开补充契约：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'UserLUTInverseDocumentContractsTests/testLACubeAnalysisSemanticsSurviveProjectReopenIntoInversePlan' \
  2>&1 | tee /tmp/lutcalc-lutanalyst-metadata-project-reopen-contract.log
```

结果：退出码 `0`；真实 `.lacube` 字节经项目资产保存、FileWrapper 重开后，反求计划仍报告 extended、`-0.25...1.25` 和 textual Double。日志 SHA-256：`1d986babb6efc7cf29456e70f4e7b116570745e00c07d912d90a8bfb98df6a57`。

## 未覆盖范围

该包没有实现 LUTAnalyst 的完整 TF／颜色分离重建、病态／多解全局证明或任意 3D 逆；没有把 metadata 变成未经定义的颜色变换。9 个旧 `.labin` 资源和 45 个直接查表注册仍按台账阻塞；Canon CP IDT、RED DRAGONColor2／IPP2、ARRI SUP2、PQ OOTF、完整 HDR／ICC 仍未完成。UI、设备、提供商、性能、签名、发布清单和 Goal 状态不变，Goal 继续保持 `active`。
