# Rec.2020 12-bit 计划色域身份验收

## 范围

本次只补充 `rec2020TwelveBit` legacy 计划的输入/输出色域身份和编码方向身份。12-bit 历史分段公式、边界常量、量化规则和 Double 路径未修改。

## 契约与实现

在既有历史公式和目录契约中新增方向、输入色域、输出色域变化检查。实现将 `analytic-rec2020-12bit-legacy-v1` 分支改为 `directionalAndSpaces`，避免不同色域计划共享身份。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter Rec2020TwelveBitContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，`Rec2020TwelveBitContractsTests` 4/4 通过。

整包 Release 日志 `/tmp/lutkit-full-20261006-rec2020-12bit.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。既有独立数值报告保持：组合 shaper 冻结参照 45 点最大尺度化误差 `4.440892098500626e-16`，HLG 与 PQ 参照结果未变化。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表 Rec.2020 完整 HDR/PQ/OOTF、其他位深历史兼容、完整 ICC、`.labin`/直接查表替代、任意三维 LUT 全根、平台或发布验收完成。
