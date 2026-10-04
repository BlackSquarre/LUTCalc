# 2026-10-04 LUTAnalyst 显式仿射模型可逆性诊断验收

## 范围

本工作包只为调用方显式提供的 `Matrix3x3` 增加结构化可逆性诊断。状态区分可唯一求逆、病态、非唯一和无效条件阈值，并报告可计算时的无穷范数条件数与单位矩阵残差。不会从任意 3D LUT 样本推断模型，不改变现有仿射逆的拒绝门槛，也不实现任意 3D LUT 反求。

## 契约与实现

先在 `Affine3DContractsTests` 增加四类契约：良态非对角矩阵、条件数超过 `1e8` 的可逆矩阵、秩亏矩阵、非法阈值。旧实现对新增 `Affine3DModelAnalysis` API 编译失败；该次 Debug 输出未单独保存日志文件。实现后，诊断复用 `Matrix3x3.inverted` 的选主元、条件检查和逆矩阵残差逻辑，不拟合或读取 LUT 节点。

奇异矩阵报告 `.nonUnique`；病态矩阵报告 `.illConditioned`；非法阈值报告 `.invalidTolerance`。只有满足指定最大条件数的可逆矩阵才报告 `.uniquelyInvertible`。数值报告未能建立逆矩阵时不伪造条件数或残差。

## 验证

工具链：Xcode 27.0（Build 27A266a），Apple Swift 6.4，arm64 macOS 27.0。

Debug 定向命令：

```sh
swift test --package-path Native/Packages/LUTKit --filter Affine3DContractsTests
```

结果：5 项通过、0 失败。Debug 为编译检查；其首次编译失败只证明新符号尚不存在，不另记为数值结果。

Release 定向命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter Affine3DContractsTests
```

结果：5 项通过、0 失败。日志 `/tmp/lutcalc-affine-model-analysis-contract-20261004.log`，SHA-256 `09a2c09c4413be7fb0325b5f55a8dd6e0cc5415153a6e0b29146831a910d58b0`。

Release 全量命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包全部通过，750 项执行、0 失败；LUTFormats 既有两项外部夹具按项目原规则跳过。日志 `/tmp/lutcalc-affine-model-analysis-full-release-20261004.log`，SHA-256 `59ea7fe9fcc7d05424c303b0e39e4022f375c1e2b8a9ba7c8c4aa0ac93c40eb`。

源码与契约 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/Affine3D.swift`：`1deed8c4857576cb2cb79e49811b5540b463d20e0dc0341aa8e5930356e2bce7`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/Affine3DContractsTests.swift`：`61a887f1c6765ed88192ee35f512bbe889b6e5e8a79dcdd88ebffb5c813e13bc`

共享包改动的 Release 平台编译也已完成：`LUTCalcMac`、generic `LUTCalcIOS` 和 generic `LUTCalcIOS` iOS Simulator 均生成 Release 产品（分别使用 `/tmp/LUTCalcAffineMacDD`、`/tmp/LUTCalcAffineIOSDD` 和 `/tmp/LUTCalcAffineSimDD`）。本次构建未签名，未作为设备运行或 UI 验收。

## 未覆盖

诊断只评估调用方显式给出的线性矩阵；不证明平移/矩阵模型与某个导入 LUT 一致，也不提供从有限 LUT 网格推断全域唯一性的证明。传递/颜色自动分离、完整分析方向和量化接入导出链、任意 3D 逆及其多解全局报告仍未完成。三平台构建虽已完成，但真机数值复核、第三方软件往返和完整发布清单不属于本工作包验收。
