# 内置 transfer 实际执行覆盖验收

## 范围

计划身份字段测试只能证明字符串不丢失，不能证明每个目录 transfer 真正接入了 `TransformPlan` 的 Double 执行路径。本轮复用当前 82 个 transfer 列表，分别构造 decode（transfer -> linear scene）和 encode（linear scene -> transfer）计划，在 `0.18` 三通道样本上实际调用 `evaluate`，并断言输出全部有限。ARRI LogC scene 与 Parameterized Gamma 按现有有效参数构造。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter TransformPlanIdentityCoverageContractsTests
swift test --package-path Native/Packages/LUTKit -c release
git diff --check
```

定向契约 2 项通过，完整 Swift Release 退出码 `0`；完整日志：`/tmp/lutkit-full-transfer-execution-20261006.log`，SHA-256：`5c52d1050b3c0d02b120d5648142bf5877e21e7e4d59f42b0fa28f859e128ebd`。该测试只证明代表性有限样本的路径接线和有限值，不替代各 transfer 的分段边界、独立公式误差、全网格或设备范围验收。

随后运行 `Scripts/verify-native-numerics.sh`，退出码 `0`；日志 `/tmp/native-numerics-transfer-coverage-20261006.log`，SHA-256：`b285f86e8794d59457a3ad3d8992be98c7e0ee37d2a6b5b2985f3e5d102b6b35`。该门禁确认既有静态、独立参照、CUBE 和 H08-H13 数值子集没有回归，仍不等同于平台、真机或发布验收。

最后运行 `Scripts/verify-native-fast.sh`，退出码 `0`；Swift 与 Node 快速契约均通过。日志 `/tmp/native-fast-transfer-coverage-20261006.log`，SHA-256：`14c09c43ec2361842c80ebb9c8f74c92a3b94279e32ef9d0d3bae4c47cb5140e`。
