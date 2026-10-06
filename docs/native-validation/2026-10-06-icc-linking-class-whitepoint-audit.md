# ICC linking profile class 与 PCS 白点组合审计

## 审计范围

本次检查 `ICCRGBProfileLink`、`ICCLUTProfileLink`、`ICCMatrixTRCProfileLink` 和 `ICCDeviceLinkTransform` 的 profile class、rendering intent 与 `wtpt` 组合。目标是寻找能够依据公开 ICC 公式独立闭合、且不会扩大既有实现边界的最小算法修复。

## 当前可验证行为

- device-link 路径明确要求 header profile class 为 `link`，并使用 header rendering intent；不把 device-link 当作普通 source/target profile。
- RGB matrix/TRC 路径只执行已验证的 relative/absolute colorimetric 子集；relative 要求 source/target media white point 一致，absolute 使用 ICC.1:2022-05 §6.3.2.2 的媒体白点比例。
- LUT profile 路径对 absolute colorimetric 使用同一媒体白点比例；perceptual、relative、saturation 依请求选择对应 A2B/B2A 标签，并保留 relative 的明确 fallback 规则。
- MPE 路径根据 `D2B0...D2B3` 与 `B2D0...B2D3` 成对标签选择 PCS，且不对 float32 PCS 额外套用传统 `wtpt` 比例。

## 未闭合组合与阻塞原因

1. 对普通 RGB/PCS linking 放宽或限制 profile class，需要覆盖 input/display/output/colorSpace/abstract 等完整 class 组合、标签可用性和 ICC 颜色管理约束。当前合成 profile 没有真实第三方逐码参照，不能仅凭 class 字段推导放行矩阵或 LUT 路由。
2. 对 LUT relative colorimetric 在不同 `wtpt` 下增加比例或拒绝，需要 ICC 规范中 media-relative PCS 的明确组合语义和独立 profile 参照。现有 matrix 路径的白点一致门槛不能直接复制到 LUT 路径，因为 LUT 标签自身可能已经包含厂商的适应与色域处理。
3. 将 profile header rendering intent 强制覆盖请求 intent，会破坏当前普通 profile linking 的显式调用契约；device-link 已单独执行该规则。

## 最小复现

合成 source/target RGB `mft2` profile 仅替换 `wtpt`：source `(0.75,1,0.5)`、target `(1.5,0.5,1)`。matrix/TRC relative 路径按契约拒绝，absolute 路径按白点比例得到可独立复核结果；LUT relative 路径若直接复用该拒绝或比例，会改变已记录的标签连接语义，但没有独立 ICC profile 逐码样本证明哪一种是正确行为。

## 结论

本轮没有安全的生产代码修改。profile class 组合、LUT relative 白点策略和完整 intent 语义标记为研究阻塞；继续保持现有明确拒绝边界，不伪造完整 ICC 验收。后续需要真实公开 profile、ColorSync/Little CMS 逐码对照或规范明确的白点组合样本后再新增契约。

