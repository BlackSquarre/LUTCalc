# LUTAnalyst 重建入口元数据边界验收

## 范围

本包只收紧已有 `ImportedLUTAnalyzer.reconstructionReport(...)` 的输入边界。调用方仍需显式提供参考输入、期望输出和 transfer／colour 插值；实现仍按 `1D transfer` 再按 `3D colour` 取样，不拟合厂商模型、不推断任意三维逆，也不改变 Double、网格或插值规则。

当分析文件的 transfer 或 colour 元数据包含不完整、非有限或倒置边界时，入口在构造采样器和读取任何样本前返回 `.invalidMetadata(...)`。域外参考样本仍返回 `.reconstructionOutsideDomain`。

## 契约先行与实现

新增契约使用 `inputMinimum: 1`、`inputMaximum: 0` 的非法 transfer 元数据，确认重建入口返回 `.invalidMetadata(.invalidBounds)`。既有缺少 colour 分节、数量不一致、空参考集、域外和显式残差契约保持不变。

修改文件：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testReconstructionRejectsMissingSectionMismatchedAndNonFiniteReferences' \
  2>&1 | tee /tmp/lutcalc-lutanalyst-reconstruction-metadata-contract-r1.log
```

结果：退出码 `0`；1 项通过。日志 SHA-256：`6e540b3883f1c30428318a232b55b60c74ca3072c42313b3b7b156e0076840f1`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lutanalyst-reconstruction-metadata-full-release-r1.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `749` 项，失败 `0`。LUTSharedUI `163`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `61`（其中 2 项既有外部夹具按原规则跳过）、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `42`。日志 SHA-256：`bdaade2d5fb92f46fc763ef23b0f47e513b5de65c484748c35623ec10b275aec`。

工具链：Swift `6.4`（swiftlang `6.4.0.34.1`），Xcode `27.0`（`27A266a`），macOS arm64 Release。

## 未覆盖范围

该入口仍不执行完整 TF／颜色自动分离、自动参考样本生成、任意 3D 逆、病态／多解全局证明或目标软件往返；方向与量化 metadata 也未接入全部导出链。9 个 `.labin`、45 个直接查表注册、Canon CP IDT、RED DRAGONColor2／IPP2、ARRI SUP2 raw、PQ OOTF、完整 HDR／ICC、UI、设备、提供商、性能、签名和发布清单仍未完成。Goal 保持 `active`。
