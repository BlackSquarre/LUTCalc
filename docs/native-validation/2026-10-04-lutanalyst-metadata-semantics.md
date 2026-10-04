# LUTAnalyst 元数据结构化语义验收

## 范围

本包只把现有 LUTAnalyst 区段中的输入范围、输入边界、插值方法和 base ISO 从旧文本字段转换为可检查的 Swift 语义。没有改变 LUT 节点、插值网格、生成精度或既有分析入口，也没有猜测未知生产方取值。

## 契约先行

先在旧实现上加入 `LUTAnalysisSectionMetadata.semantics()` 契约。旧实现没有该入口，定向 Release 编译真实失败；红灯日志为 `/tmp/lutcalc-lacube-metadata-semantics-red-20261004.log`，SHA-256：
`05324d7c2f085e8135d1f59d2d8dd8a11c4de409c9f8e4daed0b0fcb827e1cda`。

## 实现语义

- `109` 映射为 `.extended`，`100` 映射为 `.data`；缺失或空白值为 `.unspecified`。
- 未知的 range 和 interpolation 原样保存为 `.unknown(String)`，不猜测厂商语义。
- 两个边界都缺失时保持旧行为，使用 `0...1`。
- 只缺一侧边界返回 `.incompleteBounds`。
- 任一边界非有限返回 `.nonFiniteBounds`；倒置或相等边界返回 `.invalidBounds`。
- `tricubic`、`tetrahedral`、`trilinear` 转换为明确枚举；缺失值为 `.unspecified`。
- `baseISO` 原样保留为可选整数。

实现位于 `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`，契约位于 `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'LUTAnalysisFileContractsTests/testAnalysisMetadataSemantics' \
  2>&1 | tee /tmp/lutcalc-lacube-metadata-semantics-contract-20261004-r2.log
```

结果：退出码 `0`，2 项通过；日志 SHA-256：
`b80c85f373d10e793fcc188226a6078edbfca77c1c77a1dbf729c8648d2b18e5`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-lacube-metadata-semantics-full-release-20261004.log 2>&1
```

结果：退出码 `0`；当前四个 XCTest 包共执行 `490` 项，失败 `0`，LUTFormats 的既有外部夹具 `2` 项按原规则跳过。各包为 LUTSharedUI `162`、LUTFormats `58`、LUTCore `234`、LUTAnalysis `36`。完整日志 SHA-256：
`fb0f66f7988933d7b03ce4a05ee04461eb5bfae37033c5e41718893e31fa7e0a`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`：`a8e6cbd37549b1d59f53898021b258070de4d2507f763c3796ea714c5b9d5d13`
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`：`9efad582635fa605d265cbba91b5cfcf89b60b9459f044f4e033aa7e6fde12b7`

## 未覆盖范围

完整 LUTAnalyst 的 TF／颜色分离和重建、方向与量化元数据、病态模型和多解全局报告、生成计划／项目／导出接入、任意三维逆、三维域外旧实现冲突以及目标调色软件往返仍未完成。直接查表、`.labin`、Canon CP IDT、RED DRAGONColor2／IPP2、SUP2 raw、PQ OOTF、完整 HDR／ICC、UI、设备与发布清单状态不变。本包只关闭元数据结构化语义子集，Goal 保持 active。
