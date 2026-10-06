# 2026-10-06 `.labin` 研发夹具逐项复核

## 范围

本轮只复核旧 `.labin` 文件是否能被现有 Swift 兼容解析器读取，不能把“格式可读”解释成“已有公开连续算法”。文件仍是研发参照，不进入 `Native/Packages/LUTKit` 的 SwiftPM 资源，也没有被转换为 Swift 常量、压缩数据或拟合模型。

## 实际复核

对根目录九个旧资源分别设置 `LUTCALC_LABIN_SAMPLE`，运行同一条 Release 契约：

```sh
LUTCALC_LABIN_SAMPLE="$PWD/<file>.labin" \
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisFileContractsTests/testLegacyLABinFixtureIsParsedOrReportsLossyBoundary
```

九个文件均实际执行并通过：`AlexaX2.labin`、`Amira709.labin`、`Cine709.labin`、`LC709.labin`、`LC709A.labin`、`V709.labin`、`cpoutdaylight.labin`、`cpouttungsten.labin`、`s709.labin`。汇总日志：`/tmp/labin-fixtures-release-20261006.log`，SHA-256：`e1df906341d0813a6f5966ac138c88657d397f2b363027157c466c7cffb705c4`。

该契约只证明 little-endian Int32 解码、旧缩放因子、元数据读取以及遇到有损哨兵时拒绝的运行时边界。它不提供 Sony、ARRI、Panasonic 或 Canon 的公开连续定义、版本化设备范围、非灰轴语义或独立 17³/33³/65³ 参照。

## 结论

`.labin` 算法替代仍为 `0/9`。当前没有可以安全新增的 Swift `Double` 内置算法身份；继续保持研究阻塞，不改变目录、默认路由或资源状态。旧文件的 SHA-256 和替代关闭条件见[查表替代台账](2026-10-04-lut-replacement-inventory.md)。

Goal 继续保持 `active`。
