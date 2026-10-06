# ICC profile ID 校验验收

## 范围

本项覆盖 ICC profile header offset 84...99 的 16 字节 profile ID。按 ICC.1 约定，全零 ID 表示尚未计算的可接受状态；非零 ID 必须等于完整 profile 在该字段清零后的 MD5。该 ID 只用于完整性校验，不参与颜色计算。

## 先行失败契约与实现

新增两个 `PreviewContractsTests` 契约：伪造非零 ID 必须拒绝；对清零 ID 字段后的完整 profile 计算 MD5 后必须接受。生产实现新增 `ICCProfileError.invalidProfileID`，并在签名校验后执行上述规则。

## 实际结果

- Debug：`swift test --package-path Native/Packages/LUTKit -c debug --filter 'PreviewContractsTests/testICCProfile(AcceptsProfileIDComputedWithIDFieldZeroed|RejectsNonZeroProfileIDWhenDigestDoesNotMatch)'`，2 项通过，0 失败。
- Release：同命令 `-c release`，2 项通过，0 失败。
- 完整 `PreviewContractsTests` Debug 日志中 35 项通过；Release 定向日志已保存。
- 工具链：Xcode 27.0，SwiftPM，macOS arm64。

## 未覆盖范围

未覆盖第三方 profile 逐码颜色参照、全部 ICC 类型、BPC、gamut mapping、ColorSync、HDR/EDR/OOTF、`.labin`、直接查表、任意 3D 全局反求及平台/发布验收。Goal 继续保持 `active`。
