# 2026-10-05 旧 PQ OOTF 兼容内核算法验收

## 范围

本轮只把旧 `js/gamma.js:LUTGammaOOTFPQ` 的可观察分段公式保留为独立 Swift `Double` 兼容内核 `LegacyPQOOTF`。它没有注册为 `TransferID`，没有接入 `TransformPlan`，也没有被称为 BT.2100 标准 scene-to-display OOTF。原因是既有研究仍无法唯一确定旧输入单位、`Lw` 语义、`scale` 包装与 BT.2100 OOTF 参数的对应关系。

实现位置为 `Native/Packages/LUTKit/Sources/LUTCore/LegacyPQOOTF.swift`，契约位置为 `Native/Packages/LUTKit/Tests/LUTCoreTests/LegacyPQOOTFContractsTests.swift`。实现保留旧公式的 `0.0003024` 分段阈值、`267.84` toe slope、`59.5208` 对数尺度、`1.099/0.099`、`0.45` 和 `2.4`，保留 nits／normalized 包装、data/legal 仿射常数及原始阈值跳变。

## 先行契约与命令

先在内核不存在时编译契约，确认失败原因是缺少 `LegacyPQOOTF` 类型；随后实现并运行：

```sh
python3 tools/native-validation/probe-legacy-pq-ootf.py | tee /tmp/lutcalc-legacy-pq-ootf-decimal-20261005-r1.json
swift test --package-path Native/Packages/LUTKit -c debug --filter LegacyPQOOTFContractsTests | tee /tmp/lutcalc-legacy-pq-ootf-contract-debug-20261005-r1.log
swift test --package-path Native/Packages/LUTKit -c release --filter LegacyPQOOTFContractsTests | tee /tmp/lutcalc-legacy-pq-ootf-contract-release-20261005-r1.log
```

工具链为当前主机的 SwiftPM/XCTest、Python 3 `decimal`（80 位精度）和仓库现有增量 `.build`。Debug 与 Release 均为 4 项通过、0 项失败；定向 Release 没有跳过项。结果包 SHA-256 为：

| 结果 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-legacy-pq-ootf-decimal-20261005-r1.json` | `8a88ee23ebed0909b2fa8cb2243df5c01987531f5c6787110405a074cb4271af` |
| `/tmp/lutcalc-legacy-pq-ootf-contract-debug-20261005-r1.log` | `f20fb53293ba9a89150e01b1381e15c4821c67bee58e2c5c86080b6655c2352e` |
| `/tmp/lutcalc-legacy-pq-ootf-contract-release-20261005-r1.log` | `5a1657bdc1e4738559118dd5144d440f42bb1757b6c200144253470b206885a7` |

## 独立 Decimal 参照

80 位 `Decimal` 参照输出固定为：`input=0.18, peak=1000` 时 nits 为 `5.7048340980992004621530545445798066323880059788361933019892040526975149591004511`，normalized 为 `0.00057048340980992004621530545445798066323880059788361933019892040526975149591004511`。输入 `100` 时分别为 `1000` 与 `0.10`。

阈值前、阈值等号和阈值后 nits 输出分别为 `0.24004758192481813424180966019063690735760349284028251596614158516131061281545369`、同一值和 `0.24182271872239283907149890627245720301008985232372114303847520406297717057621718`。因此实现保留旧分段在阈值两侧的跳变，没有用平滑或插值掩盖它。

## 未覆盖与研究阻塞

- 没有把兼容内核接入正式 `PQTransfer`、`TransformPlan`、HDR/EDR 显示计划或任何默认预设。
- BT.2100 PQ OOTF 的参考白、系统 gamma、黑位、峰值、输入场景单位和旧 `Lw/scale` 语义仍没有一一对应的公开证据。
- 没有读取或打包厂商 LUT、旧 `.labin` 或等价采样表；`9/9` `.labin` 与 `45/45` 直接查表注册的替代台账不变。
- 本包不关闭完整 HDR、ICC、LUTAnalyst、第三方往返、平台验收或发布清单；Goal 继续保持 `active`。
