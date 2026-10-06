# ICC 传统任意通道 absolute linking 验收

## 范围

本阶段将传统 `mft2`、`mAB`、`mBA` 的任意设备通道 linking 从 relative colorimetric 扩展到公开 `A2B3/B2A3` absolute colorimetric 标签。PCS 为 XYZ 时，源 profile 的相对 PCS 按 `wtpt` 媒体白点比例缩放后进入目标 profile；设备通道仍按 profile 声明的 1...15 个通道处理。

本阶段不扩展传统 Lab arbitrary absolute：Lab 的媒体白点和 PCS 编码组合仍保留既有明确边界，避免没有独立逐码参照时猜测。实现不携带 profile、厂商 LUT、旧 `.labin` 或等价采样表。

## 失败契约

在 linking 路径只允许 relative 时，CMYK `A2B3/B2A3` synthetic profile 被拒绝。实现后缺少 absolute 标签仍返回 `missingTransformTag`，不会借用 intent 0/1/2。

## 实现

- `ICCRGBProfileLink` 新增 `traditionalXYZAbsolute` 路由和源/目标媒体白点比例。
- traditional XYZ 标签选择按请求 intent 使用 `ICCLUTIntentTransformTags`。
- generic `[Double]` API 保持任意设备通道能力；RGB convenience API 仍拒绝非三通道 profile。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCRGBProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests
```

结果：Debug／Release 各 34 项通过、0 失败；包括 CMYK absolute PCS XYZ 比例、既有 MPE absolute、传统 relative、MAB、Lab 和拒绝边界。

## 未覆盖范围

- 传统 Lab arbitrary absolute 暂不接线；黑点补偿、gamut mapping、ColorSync 和完整 profile class 仍未完成。
- 真实第三方 profile 逐码参照、目标软件往返、`.labin`、直接查表、任意 3D 全局反求和发布验收仍未完成。

