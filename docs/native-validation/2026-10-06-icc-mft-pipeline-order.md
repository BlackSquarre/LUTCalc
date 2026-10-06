# ICC mft 管线顺序验收

## 范围

本次修复覆盖用户主动导入的 ICC `mft1`／`mft2` 标签。按照 ICC.1:2022-05 §10.7 的处理顺序，输入表 A 先对设备编码解码，随后对三通道 PCS 输入应用可选 3×3 矩阵，再进入 CLUT，最后执行输出表 B。此前 Swift 路径在矩阵后才执行输入表，遇到非线性输入曲线时会改变数学结果。

## 契约与实现

先将原有“矩阵先于输入表”的契约改为非交换的输入表／矩阵样本：红通道输入表为 `[0, 0.25, 1]`，矩阵红轴为 `0.5`，单位红输入按规范顺序应得到 `0.5`。实现将 `ICCMFTTransform.sample(_:)` 的输入表 A 移到矩阵之前，并保持 CLUT 的网格尺寸、通道轴序、16 位／8 位编码和线性插值规则不变。

## 实际命令与结果

工具链：SwiftPM，系统 Swift；工作目录为 `Native/Packages/LUTKit`。

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCMFTContractsTests
```

结果：`ICCMFTContractsTests` 12 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests
```

结果：`ICCMFTContractsTests` 12 项通过，0 失败。

本次定向测试的实际结果包由 SwiftPM 输出保留在本机 `.build` 目录；未将任何 profile、厂商 LUT、`.labin` 或等价采样表加入源码或资源。

## 未覆盖范围

本项只修正传统 `mft1`／`mft2` 的 A→矩阵→CLUT→B 顺序。它不关闭 `mAB`／`mBA` 的全部元素、MPE、所有 profile class、真实第三方 profile 逐码参照、black point compensation、gamut mapping、ColorSync、HDR/EDR、`.labin` `0/9`、直接查表 `0/45` 或完整 ICC 验收。Goal 保持 `active`。
