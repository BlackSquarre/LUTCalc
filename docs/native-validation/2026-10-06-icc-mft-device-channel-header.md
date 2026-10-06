# ICC mft 设备通道与 profile header 验收

## 范围

ICC `mft1/mft2` 的 A2B 标签输入端、B2A 标签输出端属于 profile 的设备色彩空间，通道数必须与 header 的 color-space signature 一致。本项拒绝四通道 payload 配 `RGB ` header 等不一致组合；合法四通道夹具改为 `CMYK`。三通道 RGB/PCS 路径和恒等矩阵边界保持不变。

## 契约与实现

先行红测 `testMFT2RejectsDeviceChannelCountMismatchingProfileHeader` 在旧实现上确认四通道 A2B payload + `RGB ` header 被错误接受。实现按 `A2B*` 输入端、`B2A*` 输出端读取 profile 的已知通道数；不一致返回 `ICCMFTError.malformedTable`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests
git diff --check
```

红测日志：`/tmp/icc-mft-channel-red-20261006.log`；修复后日志：`/tmp/icc-mft-channel-green-20261006.log`。修复后 `ICCMFTContractsTests` Release 全部通过，退出码 `0`；差异检查退出码 `0`。

随后执行完整 LUTPreview Release 回归：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter LUTPreviewTests
git diff --check
```

结果为 `LUTPreviewTests.xctest` 共 200 项、失败 0 项，整个命令退出码 `0`。回归同时确认 device-link 的通道维度错误保持为 `dimensionMismatch`，混合 RGB/CMYK 的传统 RGB 入口保持为 `unsupportedColorSpace`。本轮修复源码为 `ICCDeviceLinkTransform.swift` 与 `ICCRGBProfileLink.swift`。

## 未覆盖

未知或私有 color-space signature、完整 profile class/intent、真实第三方 profile 逐码参照、BPC、gamut mapping、ColorSync、`.labin` 和直接查表替代仍未覆盖。
