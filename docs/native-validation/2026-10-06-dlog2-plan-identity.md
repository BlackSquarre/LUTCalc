# DJI D-Log2 与 Null legacy 计划身份验收

## 范围

本项只修复默认 DJI D-Log2 以及 Null legacy 计划身份遗漏。此前 `minimal-dlog2-v1` 和 Null legacy 分支没有记录输入/输出 transfer 和两端色域，编码、解码、矩阵、量化和 Double 计算路径均未修改。

## 契约与实现

先行红测在 `NullTransferContractsTests` 中验证 D-Log2 反向转换、D-Log2 两端色域变化，以及 Null legacy 跨色域变化；旧实现将这些计划错误地合并为同一身份。实现将两个分支改为记录 input/output `TransferID` 与 `ColorSpaceID`。

## 验证

工具链：Apple Swift 6.4，SwiftPM Release，arm64 macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter NullTransferContractsTests
git diff --check
```

结果：`NullTransferContractsTests` 定向 Release 全部通过，退出码 `0`；`git diff --check` 退出码 `0`。红测修复前的失败日志保存于 `/tmp/dlog2-red-20261006.log`，修复后日志保存于 `/tmp/dlog2-green-20261006.log`。

整包 Release 回归：命令退出码 `0`，日志保存于 `/tmp/lutkit-full-20261006-dlog2-null.log`；LUTCore 351/351、LUTCatalog 31/31、LUTAnalysis 93/93，均为 0 失败。

## 未覆盖

本项不代表 DJI D-Log-M 查表替代、其他 DJI 相机模型、`.labin`、完整 ICC/HDR/OOTF、LUTAnalyst 全局三维反求、平台或发布验收完成。
