# DaVinci Intermediate 与 DJI X3 DLog 计划色域身份验收

## 范围

本次只补充 DaVinci Intermediate legacy 与 DJI X3 DLog legacy 的计划方向和两端色域身份。已有连续公式、legacy JavaScript 参照、范围和 Double 路径未修改。

## 契约与实现

新增两个 legacy 分支的输入色域、输出色域和方向变化契约；实现统一使用 `directionalAndSpaces`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'DaVinciIntermediateContractsTests|DJIX3DLogContractsTests'
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，DaVinci Intermediate 4/4、DJI X3 DLog 4/4，共 8/8 通过；两组 legacy JavaScript 参照继续通过。

整包 Release 日志 `/tmp/lutkit-full-20261006-davinci-dji.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表完整厂商相机策略、直接查表替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。
