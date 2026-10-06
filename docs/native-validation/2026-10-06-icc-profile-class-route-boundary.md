# 2026-10-06 ICC profile class 路由边界验收

## 范围

本阶段只收紧 `ICCRGBProfileLink` 的 profile class 边界。ICC device link 有独立的 `ICCDeviceLinkTransform` 执行入口；abstract、namedColor、colorSpace 三类 profile 不描述普通设备到 PCS 的 RGB 配对端点，不能被 RGB 便利入口猜测为设备 profile。

## 先行契约

新增 `ICCRGBProfileLinkContractsTests.testNonDeviceProfileClassesAreRejectedBeforeRouteSelection`：source 使用 `abst`，target 使用 `mntr`，初始化必须返回 `.unsupportedProfileKind`，且不得进入 LUT、matrix 或 MPE 路由。

## 实际命令与结果

工具链：Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests
```

结果：`ICCRGBProfileLinkContractsTests` 39 项通过，0 失败，退出码 0。既有系统 sRGB/Display P3、Matrix/TRC、传统 XYZ/Lab、MPE 及 absolute 子集均保持通过。

## 未覆盖范围

本阶段不宣称完整 ICC profile class、全 rendering intent、BPC、通用 gamut mapping、ColorSync 等价、任意第三方 profile 逐码一致或完整多通道系统。缺少公开且唯一的统一算法时继续保持显式拒绝；不采样、不打包厂商 LUT。完整 ICC 与 Goal 仍保持 active。
