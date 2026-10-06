# ICC 传统 LUT perceptual／saturation 标签接线验收

## 范围

本阶段把已有用户导入 `mft2`、`mAB`、`mBA` 的 PCS XYZ 执行器接到传统 ICC profile linking 的两个公开 rendering intent 标签：`A2B0`／`B2A0`（perceptual）和 `A2B2`／`B2A2`（saturation）。转换仍只连接用户 profile 已提供的 PCS XYZ 管线，不新增 profile、厂商 LUT、旧 `.labin` 或等价采样表。

relative colorimetric 继续使用 `A2B1`／`B2A1`，当 intent 1 标签明确不支持时保留既有 `A2B0`／`B2A0` fallback。perceptual 与 saturation 只接受各自精确标签，不借用其他 intent。

## 失败契约

在适配器尚未允许 `A2B2`／`B2A2` 时，saturation 合成 profile 被拒绝为方向标签不支持；在 linking 外层仍只允许 relative 时，perceptual 合成 profile 被拒绝为 unsupported intent。失败输出保留在本地定向测试日志中。

## 实现

- 新增 `ICCLUTIntentTransformTags`，按 intent 选择 A2B/B2A 标签。
- `ICCMFTXYZTransform`、`ICCMABXYZTransform` 和 Lab 适配器允许 `A2B2`／`B2A2` 方向标签。
- 不改变 CLUT 网格、插值、PCS 编码、`Double` 计算或既有误差阈值。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCLUTProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCLUTProfileLinkContractsTests
```

结果：Debug 9 项通过、Release 9 项通过，0 失败。覆盖 perceptual 精确 `A2B0/B2A0`、saturation 精确 `A2B2/B2A2`、relative fallback、损坏标签拒绝、方向拒绝和 PCS 拒绝。

随后运行 `bash Scripts/verify-native-numerics.sh`，66 个独立检查退出码 `0`。结果包：`artifacts/2026-10-06-icc-traditional-intent-tags/`；`verify-native-numerics.log` SHA-256 为 `90fdbd31c0485de1869db67aadddee0a7c801f510d14473e241fbe609b2ae568`，退出码文件 SHA-256 为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`。

## 未覆盖范围

- 传统 LUT `absoluteColorimetric` `A2B3/B2A3` 仍拒绝，避免在缺少完整媒体白点语义时猜测。
- 本阶段不实现黑点补偿、gamut mapping、ColorSync、系统工作空间或显示管理。
- 真实第三方 profile 逐码参照、目标调色软件往返、完整 ICC profile class 和发布验收仍未完成。
