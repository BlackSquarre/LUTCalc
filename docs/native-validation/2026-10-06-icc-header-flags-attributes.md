# ICC 头部 flags 与 device attributes 结构验收

## 范围

本项依据 ICC.1 头部字段定义，闭合 `ICCProfileValidator` 对 offset 44 的 profile flags 和 offset 56 的八字节 device attributes 的保留位边界。flags 只允许 bit 0（embedded）和 bit 1（independent）；device attributes 只允许低四位（transparency、matte、negative、black-and-white）。字段仍只作为结构元数据，不参与颜色计算，也没有引入厂商 profile 或采样表。

## 契约与实现

先加入失败契约：flags 的高位和 device attributes 的高位必须拒绝。随后实现 `ICCProfileError.invalidProfileFlags` 与 `ICCProfileError.invalidDeviceAttributes`，并在 `ICCProfileValidation` 保留已验证的 `profileFlags`、`deviceAttributes`。合法值 `0x03`、`0x0F` 的元数据回读也有契约覆盖。

## 实际验证

工具链：SwiftPM、Apple Swift XCTest，工作区 `/Users/lingru/claude/LUTCalc`。

```text
swift test --package-path Native/Packages/LUTKit --filter PreviewContractsTests -j 4
结果：PreviewContractsTests 37 项通过；总退出码 0。

swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests -j 4
结果：PreviewContractsTests 37 项通过；总退出码 0。
```

Debug 与 Release 均覆盖合法低位回读、flags 保留位拒绝、device attributes 保留位拒绝。Release 构建仅出现既有 `ICCMFTContractsTests.swift` 未修改变量警告，没有测试失败。

## 未覆盖范围

本项不代表完整 ICC。profile platform、creator、manufacturer/model 的语义枚举、真实第三方 profile 逐码参照、BPC、gamut mapping、ColorSync、其他 MPE 元素、HDR/EDR/OOTF、`.labin`、直接查表、平台 UI 和发布验收仍未完成。Goal 继续保持 `active`。
