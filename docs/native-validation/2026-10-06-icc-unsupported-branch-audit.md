# ICC unsupported 分支公开边界审计

## 范围

本轮只检查 `ICCMABTransform`、`ICCMFTTransform`、`ICCRGBProfileLink` 及其
PCS XYZ/Lab 适配器中仍然显式拒绝的分支，寻找能依据 ICC.1:2022 直接闭合、
并且有独立逐码参照的最小子集。没有扩展 UI、系统 ColorSync、BPC 或 gamut
mapping，也没有引入任何 profile/LUT 数据。

## 失败契约和实际结果

现有契约先行锁定了以下拒绝边界：

- `mft1` 不能进入 PCS `XYZ ` 适配器；ICC 的 PCS XYZ 编码要求 unsigned
  1.15，8 位 `mft1` 没有对应编码；`ICCPCSXYZContractsTests` 已断言
  `.unsupportedEncoding`。
- `mAB/mBA` 的 PCS XYZ 适配器拒绝 8 位 CLUT；`mAB` 的 Lab/XYZ 方向和
  通道不匹配、section 重叠及非法可选阶段均有失败契约。
- `ICCRGBProfileLink` 对非 device profile class、混合 matrix/LUT 形式、
  不完整的四种 MPE intent 对、错误 PCS、RGB convenience API 的非三通道
  调用均显式拒绝；未知 MPE 处理元素继续拒绝，不猜测厂商扩展。

实际 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCMABContractsTests|ICCMFTContractsTests|ICCRGBProfileLinkContractsTests|ICCPCSXYZContractsTests'
```

结果：`ICCMABContractsTests` 19 项、`ICCMFTContractsTests` 14 项、
`ICCPCSXYZContractsTests` 7 项、`ICCRGBProfileLinkContractsTests` 39 项，
合计 79 项，0 失败；工具链为 Xcode 27 / Swift 6，macOS arm64。结果包为
`docs/native-validation/artifacts/2026-10-06-icc-unsupported-branch-audit/release.log`，
SHA-256：`340d4cf6e18c5397a554a15ba2dac6eed8a656155135ede1524632fdf8e68a41`。

## ICC.1:2022 对照与未闭合原因

ICC.1:2022 明确了 `mft`、`mAB/mBA` 的管线顺序、PCS 编码和 MPE 元素结构，
因此上述已支持分支可以执行。但规范没有为以下拒绝分支提供可脱离 profile
数据的合成公式：

1. perceptual/saturation 的通用 gamut mapping；结果依赖 profile 提供的
   A2B/B2A 数据或指定 CMM 策略；
2. black point compensation；`bkpt`/`wtpt` 标签不能唯一决定压缩曲线、
   黑位单位或 CMM 版本；
3. 未知或厂商扩展 MPE 元素，以及没有成对方向标签的 profile linking；
4. 非 device profile class 被强行当作 device endpoint；这会改变 ICC class
   语义，不能由 `mAB/mBA` 结构推断。

这些项目均缺少公开唯一算法、适用边界和独立逐码参照。线性平移、clip、
chroma compression 或任意幂函数都不能作为规范等价替代。

## 结论

本轮没有发现可安全新增的 ICC 生产子集。失败契约保持现有拒绝语义，未修改
Swift 生产代码；完整 profile class/intent、BPC、通用 gamut mapping、
ColorSync、真实第三方 profile 逐码往返仍未完成。Goal 保持 `active`。
