# ICC profile header reserved 字段验收

## 范围

本项只覆盖 ICC profile header bytes 100...127 的保留区。ICC.1 规定该区域在当前 header 中必须为零；非零值拒绝，避免未知扩展被误当作当前格式。未扩展到完整 ICC 语义。

## 先行失败契约与实现

新增 `PreviewContractsTests.testICCProfileRejectsNonZeroHeaderReservedBytes`，先将 byte 100 设为 1，修复前未抛出错误。`ICCProfileValidator.validate` 现要求 `bytes[100..<128]` 全为零，并以 `.invalidTagTable` 拒绝。

## 结果

- Debug：`swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests`，33 项通过，0 失败。
- Release：同命令 `-c release`，33 项通过，0 失败。
- 日志及 SHA-256：`docs/native-validation/artifacts/2026-10-06-icc-header-reserved/`。

## 未覆盖范围

真实第三方 profile 逐码参照、完整 ICC 类型与 intent、BPC、gamut mapping、ColorSync、HDR/EDR/OOTF、`.labin`、直接查表和任意 3D 全局反求仍未完成；Goal 保持 `active`。
