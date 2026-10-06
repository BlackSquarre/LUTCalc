# Nikon N-Log 与 Cineon 计划色域身份验收

## 范围

本次只修复 Nikon N-Log、N-Log legacy、Cineon、Cineon legacy 的计划身份缺少两端色域问题。公开/legacy 公式、Double 路径、范围和缩放规则未修改。

## 契约与实现

在 `CameraTransferIndependentContractsTests` 中新增四个 transfer 的编码方向、解码方向和输入色域变化契约。实现将共享的 `analytic-camera-transfer-v1` 分支改为 `directionalAndSpaces`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter CameraTransferIndependentContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，`CameraTransferIndependentContractsTests` 4/4 通过。90 位 Decimal 参照的最大尺度化误差：N-Log `6.498232168572208e-16`、N-Log legacy `7.178178319283952e-16`、Cineon `8.383714094919727e-16`、Cineon legacy `6.760411136787471e-13`，均低于 `2e-12`。

整包 Release 日志 `/tmp/lutkit-full-20261006-camera-transfer.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表完整相机默认策略、EI/ISO 范围、厂商 LUT 替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。
