# LUTAnalyst 显式分离重建残差验收

## 范围

本包闭合一个有明确输入边界的 LUTAnalyst 子集：调用方提供参考输入和期望输出，Swift 按分析文件的 `1D transfer` 与 `3D colour` 两个分节顺序取样，报告逐样本最大通道绝对残差、最大值、RMS 和 P99。transfer 与 colour 的插值策略必须显式传入。

该接口不从 LUT 节点拟合矩阵、传递函数或厂商模型，不执行任意三维逆，不把一次局部匹配称为全局唯一性证明。

## 契约先行与实现

新增 `LUTAnalysisReconstructionReport` 和 `ImportedLUTAnalyzer.reconstructionReport(...)`。契约覆盖：

- 线性 transfer + 线性 colour 的显式参考样本得到零残差。
- 修改一个期望输出后，最大值和 P99 残差准确报告为 `0.05`。
- 缺少 colour 分节、输入/期望数量不一致、空参考集分别返回明确错误；任一 transfer 或 colour 分节域外样本返回 `.reconstructionOutsideDomain`。
- 解析层的 `RGB64` 已拒绝非有限值；重建入口仍保留非有限检查边界。

修改文件：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testExplicitTransferColourReconstruction|ImportedLUTAnalysisContractsTests/testReconstructionRejects' \
  2>&1 | tee /tmp/lutcalc-lutanalyst-reconstruction-contract-r3.log
```

结果：退出码 `0`；2 项通过。日志 SHA-256：`b3ffc863eda6acdc2189e92e6d7a5725df0fec274b6b82b9165e6f88c5ca81b3`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lutanalyst-reconstruction-full-release-r2.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `748` 项，失败 `0`。各包汇总为 LUTSharedUI `163`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `61`（其中 2 项既有外部夹具按原规则跳过）、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `41`。日志 SHA-256：`7ea71daa9a8c71804a65c7eb763176e3e08f7be1e732e527bb3d4a8012402891`。

工具链：Swift `6.4`（swiftlang `6.4.0.34.1`），Xcode `27.0`（`27A266a`），macOS arm64 Release。

## 未覆盖范围

该包不证明任意 3D LUT 可逆，不实现局部 Jacobian、阻尼回溯、信赖域或全局唯一性；没有从旧 `.labin`、厂商 LUT 或采样数据拟合内置算法。完整 TF/颜色分离重建、自动参考样本生成、方向／量化接入所有导出路径、9 个 `.labin` 替代和 45 个查表注册替代仍未完成。Canon CP IDT、RED DRAGONColor2／IPP2、ARRI SUP2、PQ OOTF、完整 HDR／ICC、UI、设备、提供商、性能、签名和发布清单状态不变；Goal 保持 `active`。
