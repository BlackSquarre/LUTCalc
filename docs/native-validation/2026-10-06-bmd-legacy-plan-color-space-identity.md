# Blackmagic legacy Film 计划色域身份验收

## 范围

本次只补充 Blackmagic Pocket Film、Film、Film4k、Film4.6k legacy 计划的方向和两端色域身份。legacy 公式、边界、合法性和量化规则未修改。

## 契约与实现

扩展 `BMDLegacyFilmContractsTests` 与 `BMDPocketFilmContractsTests`，验证输入色域变化不会复用同一计划身份，并更新 Pocket Film 的完整身份断言。实现将两个共享分支改为 `directionalAndSpaces`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'BMDLegacyFilmContractsTests|BMDPocketFilmContractsTests'
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，`BMDLegacyFilmContractsTests` 4/4、`BMDPocketFilmContractsTests` 5/5，共 9/9 通过；冻结 JavaScript 公式和边界契约继续通过。

整包 Release 日志 `/tmp/lutkit-full-20261006-bmd.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表 Blackmagic Gen5 完整色域/相机策略、厂商 LUT 替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。
