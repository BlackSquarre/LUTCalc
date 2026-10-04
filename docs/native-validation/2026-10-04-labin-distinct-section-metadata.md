# `.labin` 独立区段元数据往返验收

## 范围

本包修复旧 `.labin` 的 transfer／colour 区段元数据边界：二进制样本布局、Int32 比例、矩阵比例、little-endian、舍入和有损哨兵保持不变；只扩展尾部 ASCII 元数据键，使两个区段可以分别保存和读回。

## 契约先行

先加入 transfer 与 colour metadata 不同的往返契约。旧实现把 transfer metadata 复制给 colour，导致 `C-Log3`、`Canon Cinema Gamut`、`109` 和 `-0.2...1.2` 全部丢失；契约在既有实现上真实执行失败 5 项。红灯日志：`/tmp/lutcalc-labin-distinct-metadata-red-20261004.log`；SHA-256：`915a6f24af236af675735ce1a1bc4c3e4e11d6c00d76fdb85e7f61ed2614fde4`。

## 实现

- 旧键 `1DTF`、`1DRG`、`1DMIN`、`1DMAX`、`SYSCS`、`INTERPOLATION`、`BASEISO` 继续表示 transfer 区段。
- 新增 `3DSYSCS`、`3DTF`、`3DCS`、`3DRG`、`3DMIN`、`3DMAX`、`3DINTERPOLATION`、`3DBASEISO` 表示 colour 区段；旧文件缺少这些键时，适用的共享旧字段仍按兼容规则提供插值、系统色域和 base ISO。
- 写出只在 colour 值与 transfer 值不同的时候写 3D 专属键，避免制造无意义重复；读取结果分别填充 `transferMetadata` 和 `colourMetadata`。

实现位于 `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`，契约位于 `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'LUTAnalysisFileContractsTests/testLABinRoundTripPreservesDistinctTransferAndColourMetadata' \
  > /tmp/lutcalc-labin-distinct-metadata-contract-20261004.log 2>&1
```

结果：退出码 `0`，1 项通过；日志 SHA-256：
`28c71489717a975fe88312ba5cc7600613e9a5e6efb11b7982852d82beeab55d`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-labin-distinct-metadata-full-release-r3.log 2>&1
```

结果：退出码 `0`；8 个 XCTest 包共执行 `743` 项，失败 `0`。LUTSharedUI `162`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `61`（其中 2 项既有外部夹具跳过）、LUTCore `234`、LUTCatalog `24`、LUTAnalysis `37`。完整日志 SHA-256：
`c70dd4f360a95e4521dfcf0740daee699dcc8a743aae98b2bae4962f3c6f3046`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTFormats/LUTAnalysisFile.swift`：`f74188a461c3365957c4c713fc1d8e85ab122060e5b89c9a5e1e719c06171b5b`
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/LUTAnalysisFileContractsTests.swift`：`4c14e18fa38b9b983162baab3e90724860585a2db91bc2ea477373871bb7e194`

## 未覆盖范围

本包只关闭 `.labin` 区段 metadata 的读写边界，不代表完整 LUTAnalyst TF／颜色分离、方向／量化接入生成链、病态／多解报告或任意 3D 逆完成。9 个旧 `.labin` 资源仍禁止打包，目标调色软件往返、完整格式互操作、UI、设备、提供商、发布和真实全量清单仍未完成，Goal 保持 active。
