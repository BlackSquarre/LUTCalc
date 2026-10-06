# ICC MPE device-link `mpet` 验收

## 范围

本项补齐 ICC device-link `A2B0` 的 `mpet` 处理元素路由。`ICCMPETransform` 原有的 `matf`、`clut`、曲线和 ACS 元素执行器被复用；device-link 输出通道数取自 profile 的输出色彩空间。未改变 `mft1`、`mft2`、`mAB`、`mBA` 的既有路由和错误语义。

## 契约与实现

先加入 `ICCDeviceLinkContractsTests.testDeviceLinkUsesA2B0MPEMatrix`，旧实现以 `unsupportedTagType("mpet")` 失败。实现后增加 device-link 专用 MPE 解析入口和 `mpet` route，并以对角 `matf` 矩阵验证 RGB 三通道缩放。

## 实际命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCDeviceLinkContractsTests.testDeviceLinkUsesA2B0MPEMatrix
1 项通过

swift test --package-path Native/Packages/LUTKit -c release --filter 'ICCDeviceLinkContractsTests|ICCMPEContractsTests'
35 项通过，0 失败

git diff --check
通过
```

Debug 新增契约输入 `(0.4, 0.6, 0.8)`，三通道缩放矩阵 `0.5I` 的输出为 `(0.2, 0.3, 0.4)`，误差为 0。Release 复验包含 `ICCDeviceLinkContractsTests` 7 项和 `ICCMPEContractsTests` 28 项。

原始测试输出及 SHA-256 保存在 `docs/native-validation/artifacts/2026-10-06-icc-mpet-device-link/`。

## 未覆盖范围

本项只关闭 device-link `A2B0` 的 `mpet` 路由子集，不代表完整 ICC。真实第三方 device-link 的逐码 LittleCMS 参照、`mAB` 全元素组合、`mBA` 反向执行、BPC、gamut mapping、ColorSync、完整 profile class/intent 组合以及发布验收仍未完成。Goal 继续保持 `active`。
