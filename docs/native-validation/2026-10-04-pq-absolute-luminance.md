# 2026-10-04 PQ 绝对亮度单位边界验收

## 范围

本轮只闭合 SMPTE ST 2084／BT.2100 标准 PQ 标量的绝对亮度单位边界。`PQTransfer` 原有归一化 API 仍以 `0...1` 表示相对于 10,000 cd/m² 的绝对亮度；新增 API 明确使用 cd/m²（nits）。没有实现或猜测场景到显示的 PQ OOTF、显示峰值映射、参考白／黑位或 HDR/EDR 设备语义。

## 契约先行

先只加入契约并运行：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'NumericContractsTests/testRec2100PQExplicitNitsContractUsesTenThousandCdPerSquareMeterReference|NumericContractsTests/testRec2100PQAbsoluteNitsRoundTripEvery16BitCode' \
  2>&1 | tee /tmp/lutcalc-pq-nits-contract-red-20261004.log
```

旧实现按预期编译失败：`PQTransfer` 尚无 `referencePeakNits`、`encodeAbsoluteLuminanceToData` 和 `decodeDataToAbsoluteLuminance`。该红灯只证明契约先行，不计为生产算法失败。

## 实现与结果

`PQTransfer` 新增：

- `referencePeakNits = 10_000.0`；
- `encodeAbsoluteLuminanceToData(_:)`，输入范围为 `0...10_000` cd/m²；
- `decodeDataToAbsoluteLuminance(_:)`，输出为 cd/m²。

新增 API 只调用既有解析式 Double 实现，不保存 LUT、采样表或任何厂商资源。定向 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'NumericContractsTests/testRec2100PQExplicitNitsContractUsesTenThousandCdPerSquareMeterReference|NumericContractsTests/testRec2100PQAbsoluteNitsRoundTripEvery16BitCode' \
  2>&1 | tee /tmp/lutcalc-pq-nits-contract-20261004-r2.log
```

结果：2 项通过，退出码 `0`。对 `0...65535` 全部 16-bit PQ code 做单调性和绝对亮度边界检查，逐码重新编码的最大 code 误差为 `2.708944180085382e-14`，契约阈值为 `4e-14`。

完整 Release 回归：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  2>&1 | tee /tmp/lutcalc-pq-nits-full-release-20261004.log
```

结果：`swift test --list-tests` 列出 `733` 项；完整测试退出码 `0`，失败 `0`。LUTFormats 的 2 项既有外部夹具仍按原规则跳过。日志 SHA-256：

```text
539c66cb394016e5f562651c1d78159942c6ffd3a0490d79a28e552abea34738
```

定向日志 SHA-256：

```text
e98767c288a36a463a899266eadd1ad795fed85bf7bef02ac8c4f134d9e76fd0
```

生产源码 `PQTransfer.swift` SHA-256：

```text
e240657bb72f454d990b72bd9922cb07b11cc86051176b2a053a298edc148d14
```

契约源码 `NumericContractsTests.swift` SHA-256：

```text
0914b8ed62cea4474f8bc4ce9a44963c8af5868ee2cdd944697cb520e0320e14
```

## 未覆盖范围

- PQ OOTF 的历史 LUTCalc 公式与 BT.2100 场景到显示语义仍存在输入单位、`Lw`／scale 和分段跳变冲突，继续按研究阻塞处理。
- 仍没有自动峰值、参考白／黑位策略、四种 HDR 显示变体、完整限幅／裁剪统计或真实 HDR/EDR 参照。
- 本记录不关闭完整 HDR、ICC、LUTAnalyst、H11/FULL 范围或 Goal；Goal 保持 `active`。

