# ICC rendering intent 剩余边界复核

日期：2026-10-06。范围仅限 ICC 非 UI 算法路由；Goal 继续保持 `active`。

## 当前已闭合的可追溯子集

当前 Swift 路由已对用户主动提供的 profile 明确选择 intent 对应标签：

- perceptual：`A2B0` / `B2A0`；
- relative colorimetric：优先 `A2B1` / `B2A1`，仅在元素类型或编码明确不支持时回退 `A2B0` / `B2A0`；
- saturation：`A2B2` / `B2A2`；
- absolute colorimetric：传统 LUT 路由选择 `A2B3` / `B2A3` 并按 `wtpt` 比例连接，MPE 路由选择 `D2B3` / `B2D3`，不重复插入媒体白点缩放。

这些路径只执行用户 profile 已提供的变换元素，不内置厂商 LUT、旧 `.labin` 或等价采样表。matrix/TRC、传统 Lab、MPE 和 LUT 路由的 profile class、PCS、通道数、方向及缺失成对标签均有显式拒绝边界。

## 契约与实际结果

执行命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCLUTProfileLinkContractsTests|ICCRGBProfileLinkContractsTests|ICCMatrixTRCContractsTests'
```

工具链：Xcode 默认 SwiftPM Release；macOS host。结果：`LUTPreviewTests` 定向执行 74 项，0 失败，退出码 0。覆盖当前四种 intent 的 synthetic 公式夹具、系统 sRGB/Display P3 matrix/TRC 夹具、不同媒体白点 absolute 缩放，以及 MPE/Lab/任意设备通道路由。

## 未能安全扩展的边界

仍不能把上述 synthetic 夹具解释为完整 ICC intent 验收：

1. 真实第三方 profile 的 `A2B*`/`B2A*`、`D2B*`/`B2D*` 逐码结果尚无跨 CMM 独立参照；
2. perceptual 与 saturation 的压缩、色域映射和黑点策略由 profile 元素及 CMM 策略共同决定，不能仅凭 header intent 或 `bkpt` 推导唯一通用公式；
3. absolute colorimetric 的 profile-specific PCS、厂商 MPE 扩展、非 RGB 工作流和 ColorSync 行为仍缺少可复现的公开联合契约；
4. 因此不新增“自动 fallback 到另一个 intent”、通用 BPC、通用 gamut mapping 或 ColorSync 等价实现，也不放宽现有拒绝边界。

## 后续所需证据

要继续关闭该范围，必须保存不入库的真实 profile 字节校验、LittleCMS/ColorSync 或其他独立 CMM 的逐点输出、profile 标签摘要、输入域与误差阈值，并先写失败契约再决定是否扩展 Swift Double 路由。当前证据不足，故本轮仅记录研究阻塞。

本记录不勾选完整 ICC、H13、FULL-03 或 Goal；`.labin`、直接查表、HDR/OOTF、LUTAnalyst 全局反求和平台发布范围保持原状态。
