# BT.2100 HLG 计划色域身份验收

## 范围

本次只修复 `rec2100HLG` 计划版本缺少输入/输出色域的问题。未修改 BT.2100 HLG OETF、逆函数、HLG OOTF、网格、位宽或阈值。

## 契约与实现

新增 `HLGPlanIdentityContractsTests`，先验证 HLG 解码与编码方向、以及相同方向但不同输入/输出色域必须生成不同 `planVersion`；另以 0.18 参考值确认已有 OOTF 数值路径不变。实现将 HLG 分支从 `directional` 改为 `directionalAndSpaces`。

## 验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter HLGPlanIdentityContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向结果：退出码 `0`，`HLGPlanIdentityContractsTests` 2/2 通过。

整包结果：`swift test --package-path Native/Packages/LUTKit -c release --quiet` 退出码 `0`，全量 Release 测试通过；`git diff --check` 退出码 `0`。

本记录不代表完整 HDR/EDR、PQ OOTF、自动峰值、平台或发布验收完成。
