# BT.601 525／625 传递函数复审

## 范围

本轮只复核 TransferID 与 AlgorithmCatalog 是否可以新增 BT.601 525／625 传递函数，不修改既有生产实现，不把 Rec.709 候选式注册为 BT.601 身份。

## 契约与结果

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter BT601TransferAuditContractsTests
```

Apple SwiftPM Release 工具链执行 `BT601TransferAuditContractsTests` 2 项，失败 0，退出码 0。日志：`artifacts/2026-10-06-bt601-transfer-reaudit/release.log`；SHA-256：`116eb09722042ee35e151953fded7d5a42644b76b6385fbaa95de0c30157e3c1`。

契约覆盖：

- `BT.601 525` 与 `BT.601 625` 不得悄然解析为目录 transfer；
- Rec.709 候选分段式的 Decimal 锚点保持独立探针数值；
- 通用 8-bit 视频范围 `16...235/255` 不被解释为 BT.601 完整制式。

## 结论

公开资料目前只闭合 BT.601 两套原色矩阵。没有同一标准版本同时给出可追溯 OETF、525／625 代码范围、采样与矩阵语义以及 LUTCalc legacy 包装的联合来源和独立逐码参照。因此继续拒绝新增 transfer，阻塞计数保持不变；本轮不关闭 BT.601 transfer 缺口，也不增加厂商采样数据。

## 关闭条件

取得同一标准版本的联合来源，并用独立 Decimal／逐码参照覆盖 OETF、代码范围、矩阵和项目包装后，才可新增独立 `TransferID` 与目录描述。
