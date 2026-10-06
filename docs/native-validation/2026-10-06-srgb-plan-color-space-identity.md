# sRGB 计划色域身份验收

## 范围

本次只补充 W3C sRGB 与 LUTCalc legacy sRGB 计划版本中的两端色域身份。两种 transfer 公式、分支边界和数值路径未修改。

## 契约与实现

扩展 `SRGBPlanIdentityContractsTests`，分别覆盖 W3C 与 legacy transfer 的输入/输出方向，以及仅改变输入或输出色域时的身份变化。修改前定向 Release 测试中，色域身份测试的 6 条断言失败：两种 transfer 各有输入色域、输出色域冲突和缺失色域字段。

实现将 sRGB 计划改为统一使用 `directionalAndSpaces`，编码方向、解码方向及 `inSpace`/`outSpace` 均进入 `planVersion`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter SRGBPlanIdentityContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，4/4 通过。整包 Release 日志 `/tmp/lutkit-full-20261006-srgb.log` 中所有 XCTest suite 均报告通过，无失败项；LUTAnalysis 93/93 通过。附加数值报告中 HLG Decimal 最大尺度化误差 `4.974256639474225e-16`，HLG EOTF 最大尺度化误差 `7.771561172376096e-16`，PQ 16-bit 往返最大编码误差 `2.708944180085382e-14`。`git diff --check` 退出码 `0`。

## 未覆盖

本记录不证明所有 transfer 分支的计划身份均已审计，也不代表完整 HDR/ICC、`.labin`/直接查表替代、任意三维 LUT 全根、平台、真实文件往返或发布验收完成。
