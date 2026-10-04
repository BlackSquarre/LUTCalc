# LUTAnalyst 量化与字节语义验收

## 范围

本包只把 `.lacube` 文本和旧 `.labin` 二进制的数值表示规则结构化暴露。它没有改变节点、网格、插值、生成路径或阈值，也没有把旧 `.labin` 研发资源变成内置算法资源。

## 契约先行

先在旧实现上加入两项契约：文本格式标记为 `Double`，旧 `.labin` 暴露样本缩放、矩阵缩放、little-endian、`floor(value * scale + 0.5)` 舍入和 `2,136,746,230` 有损哨兵；未知来源不得猜测。旧实现没有 `quantizationSemantics`，定向 Release 编译真实失败。红灯日志：`/tmp/lutcalc-lacube-quantization-semantics-red-20261004.log`；SHA-256：`1c65d6acb8c11b4cb10769e4acdc18da719897a54ea4d35bd398191dd3a647c5`。

## 实现

新增 `LUTAnalysisQuantizationSemantics`：

- `.lacube` 明确为 textual Double，不附带整数缩放或舍入声明。
- `.labin` 明确为 little-endian Int32；样本比例 `2^30`，矩阵比例 `2^30 / 10`，有损哨兵 `±2,136,746,230`，写出舍入复现 `floor(scaled + 0.5)`。
- 其他来源返回 `.unknown`，不根据文件内容推断量化规则。

实现位于 `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`，契约位于 `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`。解析和写出继续使用已有有限值、范围、有损边界和 little-endian 检查。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'LUTAnalysisFileContractsTests/testAnalysisQuantizationSemantics' \
  > /tmp/lutcalc-lacube-quantization-semantics-contract-20261004.log 2>&1
```

结果：退出码 `0`，2 项通过；日志 SHA-256：
`559f0968290f5968ee5602b6e439dec5ecaf13de564f2a40ac6ef562d599b1ae`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lacube-quantization-semantics-full-release-20261004.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `739` 项，失败 `0`。LUTFormats 执行 `58` 项，其中既有外部夹具 `2` 项按原规则跳过；其余包为 LUTSharedUI `162`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `36`。完整日志 SHA-256：
`e8d972b1e96ebd3e809dfd944b1582731e2a8673111677ae03f7755db34d6a6f`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`：`0a9eb709bd9498781a5a70405771f38ff1a05cb5e1117dce7ca4f0ec3d765b92`
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`：`67ef81a364c52739f4801ce2ce104ac02a1d4737f71e16974e099dc120ef6430`

## 未覆盖范围

本包没有关闭完整 LUTAnalyst 的 TF／颜色分离重建、方向／量化兼容接入、病态／多解报告、任意 3D 逆、生成计划／项目／导出或目标软件往返；也没有替代 9 个 `.labin` 资源和 45 个直接查表注册。旧格式的目标软件实测、全部格式批量和全量清单仍未完成，Goal 保持 active。
