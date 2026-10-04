# ICC relative colorimetric 标签优先级验收

## 范围

本轮只处理 ICC.1:2022 第 8.10.2 条在已支持 RGB、D50 PCS `XYZ `／`Lab `、三通道 LUT linking 子集中的标签选择：relative colorimetric 优先尝试 `A2B1`／`B2A1`，缺少或处理元素明确不支持时回退到 `A2B0`／`B2A0`。没有新增 profile 类型、黑点补偿、gamut mapping、系统 ColorSync 接入或 UI 范围。

## 实现与契约

- `ICCRelativeIntentTransformTags` 提供按优先级排列的候选标签。
- `ICCLUTProfileLink` 和 `ICCRGBProfileLink` 的 Lab 路由先尝试 intent 1 标签。
- 只有受支持标签类型之外的明确 unsupported tag type/direction 才触发下一候选；解析失败、损坏长度、域错误和非有限值不会被 fallback 掩盖。
- 新增 LUT profile 契约：intent 1 优先、`mft1` 不支持时回退到 intent 0、损坏的 intent 1 `mft2` 不得被 intent 0 掩盖。

## 实际命令与结果

工具链：Xcode 27.0 (27A266a)，Swift 6.4，arm64 macOS。

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter 'ICC(LUTProfileLink|RGBProfileLink|MFT|MAB|PCSXYZ|LabPCS)ContractsTests'
```

结果：50 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit -c release
```

结果：退出码 0；LUTKit 全量 Release 测试 0 失败。原始日志：[lutkit-release.log](artifacts/2026-10-04-icc-relative-intent/lutkit-release.log)。SHA-256：`14c685ac2d8dbc0649f57955ecf16accc7a998a2b215f3efc3f9b236e4d49ee9`。

## 未覆盖与状态

本记录不代表完整 ICC 完成。profile class 其余标签、通道数、其他 rendering intent、黑点补偿、gamut mapping、HDR/EDR、系统色彩管理、第三方软件往返和发布验收仍未完成。Goal 保持 `active`。
