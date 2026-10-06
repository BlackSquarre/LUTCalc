# ICC 任意通道路由审计

## 审计范围

本次复核用户导入 ICC 的传统 `mft1`／`mft2`／`mAB`／`mBA` 与 MPE linking 路由，重点检查设备通道数、PCS 方向、rendering intent 和 device-link `A2B0` 选择是否存在可由公开规范直接闭合的剩余子集。

## 当前已闭合边界

- `ICCMABTransform` 支持声明的 1...15 个输入和输出通道、曲线、矩阵、CLUT 和 `mAB`／`mBA` 固定顺序；输入输出维度不再硬编码为 RGB。
- `ICCMFTXYZTransform`、`ICCMABXYZTransform` 支持 arbitrary device array 与 PCS `XYZ ` 的 16 位编码；8 位 PCS XYZ 明确拒绝。
- `ICCMFTLabTransform`、`ICCMABLabTransform` 支持 PCS `Lab ` 的 arbitrary device array，复用 D50 Lab 编码和 `Double` 计算。
- `ICCRGBProfileLink` 对 traditional XYZ/Lab 路由支持 relative 和 absolute colorimetric 的对应 intent 标签，并按两个 profile 的 `wtpt` 做绝对白点比例；RGB 便捷 API 对非三通道仍明确拒绝，generic `[Double]` API 才执行任意设备通道。
- `ICCDeviceLinkTransform` 仅执行 device-link 规范声明的 `A2B0`，校验 profile class、头部 intent、通道数和 payload 方向；`mBA ` 等反向标签明确拒绝。

## 仍不能安全扩大的范围

普通 profile linking 的 BPC、通用 gamut mapping、ColorSync 语义以及真实第三方 profile 逐码参照尚未闭合。其他 profile class、非传统 tag 组合和完整 intent 组合也不能由 synthetic identity 夹具推断。MPE arbitrary route 的 PCS 适配同样需要真实 profile 与独立参照才能扩大覆盖。

## 实际验证

工具链：Apple Silicon macOS，Xcode 27.0 (27A266a)，Swift 6.4。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMABContractsTests --filter ICCPCSXYZContractsTests --filter ICCDeviceLinkContractsTests --filter ICCLUTProfileLinkContractsTests
```

结果：上述四个测试套件共 43 项，0 失败。验证覆盖任意 4 通道设备数组、XYZ/Lab absolute 白点缩放、方向错误、PCS/编码拒绝、device-link `A2B0` 约束和 RGB 便捷 API 边界。

## 未覆盖范围

本记录不声称完整 ICC、BPC、gamut mapping、ColorSync、第三方 profile 逐码互操作、UI、真机或发布验收完成；Goal 继续保持 `active`。
