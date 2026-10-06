# 格式解析器 Release 回归

## 命令

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'CubeContractsTests|SPI1DContractsTests|SPI3DContractsTests|ThreeDLContractsTests|ILUTContractsTests|OLUTContractsTests|AssimilateLUTContractsTests|VLTContractsTests|NCP0100ContractsTests|UnsupportedFormatVariantContractsTests|FormatIndependentQuantizationContractsTests'
```

## 结果

LUTFormats Release 定向回归执行 `61` 项，失败 `0`。覆盖 CUBE、SPI1D、SPI3D、3DL、ILUT、OLUT、Assimilate、VLT、NCP0100 读入以及不支持变体拒绝和独立量化参照。

其中 1 项跳过是 `NCP0100ContractsTests.testPublicSpecimenWhenProvided`，因为当前环境没有通过 `LUTCALC_NCP0100_SPECIMEN` 提供的公开 NCP 样本；没有把该项计为通过，也没有生成或写出 Nikon 兼容文件。

## 未覆盖范围

本回归证明 Swift 解析、写出和拒绝边界没有回归，不证明厂商私有方言完整互操作、NCP 写出、目标调色软件往返、`.labin`/直接查表替代或全量平台发布验收。Goal 保持 `active`。
