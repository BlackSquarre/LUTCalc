# ICC profile 版本字段边界验收

## 范围

本验收只覆盖 ICC profile header offset 8...11 的版本字段结构边界。ICC.1 使用 8.8.8.8 编码保存主版本、次版本和修订信息；低 16 位为保留位，必须为零。此项不宣称支持所有版本语义，也不改变 profile 解析或色彩转换路径。

## 先行契约

在实现前新增 `PreviewContractsTests.testICCProfileVersionRejectsNonZeroReservedLowBits`。构造最小 132 字节 profile，将 offset 11 设为 `1`，旧实现未拒绝该保留位，契约为红灯。

## 实现

`ICCProfileValidator` 现在读取版本为 `UInt32` 的大端值并暴露为 `ICCProfileValidation.profileVersion`。当 `(version & 0x0000FFFF) != 0` 时返回 `.invalidProfileVersion`。版本值为零继续兼容既有合成夹具；例如 `0x04300000` 可被验证并原样保留。

## 验证命令与结果

工具链：SwiftPM、Apple Swift XCTest，macOS arm64。

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests
```

结果：`PreviewContractsTests` 42 项通过；包含版本合法值、保留位拒绝及既有 ICC header 契约。

```text
swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests
```

结果：`PreviewContractsTests` 42 项通过；Release 构建成功，0 失败。

## 未覆盖范围

- 未将版本号映射为完整的 ICC 版本能力矩阵。
- 未对未知未来主版本做兼容性推断。
- 未覆盖真实厂商 profile 逐码参照、ColorSync、BPC、gamut mapping 或完整 ICC intent。
- 此项不关闭 `.labin`、直接查表、任意三维反求、HDR/OOTF 或平台发布验收。

Goal 继续保持 `active`。
