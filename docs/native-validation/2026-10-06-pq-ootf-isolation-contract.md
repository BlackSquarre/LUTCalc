# PQ OOTF 标准路径隔离契约验收

日期：2026-10-06。

## 范围

本轮只验证标准 `rec2100.pq-reference.v1` 与历史 `LegacyPQOOTF` 的身份隔离。标准路径使用 ST 2084／BT.2100 的绝对 PQ 标量；历史路径保留旧 LUTCalc 的百分比输入、`Lw`、`scale`、knee 和 data/legal 仿射包装。没有把历史公式注册为 `TransferID`，也没有接入 `TransformPlan`。

## 先行契约

`RegistryContractsTests.testRec2100PQReferenceRemainsSeparateFromLegacyOOTF` 覆盖：

- 内置目录没有 `PQ OOTF` transfer 或 `rec2100.pq-ootf.v1` 预设；
- 标准 PQ 预设没有 HLG OOTF 设置；
- 标准 `TransformPlan` 对 0.18 归一化亮度保持 PQ 编码往返；
- 历史公式仍保留冻结输出 `5.704834098099198` nits，且不等于标准 PQ 解码得到的绝对亮度。

## 实际命令与结果

工具链：Apple SwiftPM Release，Swift 6 工具链。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testRec2100PQReferenceRemainsSeparateFromLegacyOOTF
```

结果：定向测试 `1` 项、`0` 失败，退出码 `0`。构建阶段仅有既有未修改测试文件的编译警告。

随后应继续运行 `LegacyPQOOTFContractsTests`、`BT2100HLGReferenceOOTFContractsTests` 和 `BT2100HLGReferenceEOTFContractsTests`；本记录不替代完整 Swift Release 和原生数值门禁。

## 仍未覆盖与研究阻塞

旧 `LUTGammaOOTFPQ` 的输入单位、`Lw/100`、`scale`、BT.709 风格 knee、2.4 幂次及黑位／参考白语义没有公开标准的一一对应关系，knee 两侧约有 `1.7751367975487e-3` nits 跳变。BT.2100／ST 2084 的 PQ 绝对亮度定义不能单独确定该场景到显示 OOTF。因而本轮不猜测连续公式、不平滑历史跳变、不新增采样表。

完整 PQ OOTF、自动峰值、HDR/EDR 设备语义、真实显示参照和完整发布验收仍未完成；Goal 保持 `active`。
