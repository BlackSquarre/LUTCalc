# ICC 传统任意通道 Lab absolute linking 验收

## 范围

本阶段补齐用户导入的传统 `mft2`、`mAB`、`mBA` profile 在 Lab PCS 下的任意设备通道 absolute colorimetric linking。实现沿用已验收的 D50 CIELAB↔XYZ `Double` 公式，并按源、目标 profile 的 `wtpt` 做媒体白点比例缩放；通道数组保持 `[Double]`，RGB convenience API 继续拒绝非三通道输入。

本阶段不实现黑点补偿、gamut mapping、ColorSync、真实第三方 profile 逐码参照或完整 ICC，也不改变任何网格、位宽、插值和误差阈值。

## 契约与结果

- 新增 `testTraditionalAbsoluteLabMABProfileLinkScalesCMYKPCS`，先验证 CMYK Lab absolute 路由缺失，再接线实现。
- 独立预期编码值为 `0.2935715779621544`、`0.4477083911771103`、`0.5522887827367406`；结果证明该路径不是 RGB 恒等映射。
- `swift test --package-path Native/Packages/LUTKit -c debug --filter ICCRGBProfileLinkContractsTests`：35 项通过，0 项失败。
- `swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests`：35 项通过，0 项失败。
- `git diff --check`：通过。

## 未覆盖范围

传统 ICC 的完整 profile class、全部标签变体、真实 profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR、`.labin` 资源替代、直接查表注册替代和 LUTAnalyst 任意三维全局反求仍未完成。Goal 保持 `active`。
