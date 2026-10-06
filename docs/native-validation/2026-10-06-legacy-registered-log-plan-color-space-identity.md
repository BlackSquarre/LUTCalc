# Legacy Registered Log 计划色域身份验收

## 范围

本次只补充 Bolex Log、Panalog、DJI X5/X7/X9 DLog、GoPro Protune legacy 计划的方向和两端色域身份。已有连续公式、legacy JavaScript 参照、边界和 Double 路径未修改。

## 契约与实现

在既有四组公式、非有限值和目录契约上新增输入色域、输出色域及方向变化测试；实现将共享计划分支改为 `directionalAndSpaces`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter LegacyRegisteredLogContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，`LegacyRegisteredLogContractsTests` 4/4 通过；四组 legacy JavaScript 参照和非有限值契约继续通过。

整包 Release 日志 `/tmp/lutkit-full-20261006-legacy-registered.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表完整厂商相机策略、GP-Log2 完整语义、直接查表替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。
