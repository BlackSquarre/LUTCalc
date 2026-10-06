# ICC 真实系统 profile 参照审计

## 范围

本轮只审计当前 macOS 可读取的真实 ICC profile，寻找能够在不猜测色彩管理语义的前提下补齐纯 Swift 逐码或往返契约的范围。未修改 UI、ColorSync 调用或生产算法，也没有把系统 profile 打包进 App。

## 真实 profile 清单

在本机检查了以下系统 profile：`sRGB Profile.icc`、`Display P3.icc`、`AdobeRGB1998.icc`、`ITU-709.icc`、`ITU-2020.icc`、`DCI(P3) RGB.icc`、`ACESCG Linear.icc`、`ROMM RGB.icc`、`Generic RGB Profile.icc`，以及 `/Library/ColorSync/Profiles/Displays/` 下当前显示器 profile。

这些 RGB profile 均可做结构校验；系统 sRGB、Display P3 和真实显示器 profile 已有 Matrix/TRC 生产路径契约。它们的 PCS、媒体白点和 TRC 并不统一，不能把不同 profile 的结果直接当作同一算法身份。

## 独立参照复现

工具链：macOS 26 SDK 环境、LittleCMS 2.19 `transicc`。使用四个输入样本 `(0.17,0.63,0.91)`、`(0.25,0.50,0.75)`、`(0.90,0.10,0.20)`、`(1,1,1)`，执行：

```sh
transicc -i'/System/Library/ColorSync/Profiles/Display P3.icc' \
  -o'/System/Library/ColorSync/Profiles/sRGB Profile.icc' -t1 input.cgats output.cgats
```

LittleCMS 对该组系统 profile 的输出为：

```text
(0.05058, 0.6498, 0.9455)
(0.1984, 0.4981, 0.7471)
(1.047, 0.05058, 0.1984)
(0.9961, 0.9961, 0.9961)
```

这些结果是外部实现的 16 位/显示设备转换输出（含 profile 自身的渲染意图、裁剪和量化行为），不能证明本项目的纯 Swift `Double` 语义。当前实现明确区分 relative/absolute、PCS 白点和 out-of-gamut；将上述截断输出硬编码为预期值会把 ColorSync/LittleCMS 策略误当成 ICC 基础公式，因此没有新增跨 profile 逐码断言。

## Release 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCRGBProfileLinkContractsTests|ICCDeviceLinkContractsTests|PreviewContractsTests'
```

结果：`LUTPreviewTests` 选定范围 `91` 项通过、`0` 失败；其中 `ICCDeviceLinkContractsTests` 7 项，`ICCRGBProfileLinkContractsTests` 39 项，`PreviewContractsTests` 44 项。系统 sRGB、Display P3、真实显示器 profile 的结构/Matrix/TRC 子集均通过。

## 未覆盖与结论

真实系统 profile 参照没有安全地关闭完整 ICC 的 BPC、通用 gamut mapping、ColorSync 逐码一致性、所有 profile class/intent 组合、非 Matrix/TRC 的第三方 profile 或目标软件往返。真实 profile 路径保持现有已验证子集；Goal 继续保持 `active`。
