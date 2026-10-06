# ICC tag reserved 字段边界验收

## 范围

本项只覆盖 ICC tag payload 固定头的 4 字节 reserved 字段。依据 ICC.1 tag type 结构，该字段必须为零；非零值不得进入后续解析或转换。未扩展到完整 ICC 类型覆盖、BPC、gamut mapping、ColorSync 或第三方逐码参照。

## 先行失败契约

新增 `PreviewContractsTests.testICCProfileRejectsNonZeroTagTypeReservedBytes`，将 `text` payload 的 reserved 首字节改为 `1`。生产修复前测试实际失败（未抛出 `invalidTagPayload`），证明边界缺口存在。

## 实现

`ICCProfileValidator.validate` 在确认 payload 至少 8 字节后，要求 `[4..<8]` 四个 reserved 字节全部为零；否则抛出 `.invalidTagPayload`。该校验位于所有已知和未知 tag 类型共用入口，不保存或改变用户 LUT 数据。

## 命令与结果

- Debug：`swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests`，PreviewContractsTests 32 项通过，0 失败。
- Release：`swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests`，PreviewContractsTests 32 项通过，0 失败。
- 产物日志与 SHA-256：`docs/native-validation/artifacts/2026-10-06-icc-tag-reserved/`。

## 未覆盖范围

真实第三方 ICC profile 逐码参照、所有 MPE 元素、BPC、gamut mapping、ColorSync、HDR/EDR/OOTF、`.labin` 与直接查表、任意 3D LUT 全局反求仍未完成；Goal 保持 `active`。
