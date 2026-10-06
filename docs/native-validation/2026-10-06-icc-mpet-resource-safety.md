# ICC MPE 资源边界验收

## 范围

本轮只处理用户导入 ICC `multiProcessElementsType`（`mpet`）解析时的整数乘加溢出边界，不扩展支持的 ICC 元素或 profile 功能范围。

## 契约与实现

- 新增 `ICCMPEContractsTests.testMPETElementCountOverflowIsMalformedWithoutAllocatingElementTable`：把最小合法 `mpet` 的元素计数改为 `UInt32.max`，要求在读取元素表前返回 `.malformed`，测试不分配巨型 payload；另新增 CLUT 17 输入通道拒绝契约，避免超出 ICC 16 槽网格头时索引越界。
- 元素表大小、元素位置、`matf` 参数数量与字节数、`cvst` 曲线表和 breakpoint、`parf`/`samf` 段长度及样本地址统一使用溢出安全加乘。
- 合法矩阵、曲线、采样曲线、CLUT、ACS、XYZ/Lab 入口契约保持原有结果。

## 实际命令与结果

工具链：macOS Swift Package Manager，Swift 6.x，Debug／Release 测试。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMPEContractsTests
```

结果：`ICCMPEContractsTests` Debug／Release 各 25 项通过，退出码 0；`Scripts/verify-native-numerics.sh` 退出码 0。完整输出保存在：

`docs/native-validation/artifacts/2026-10-06-icc-mpet-resource-safety/icc-mpet-debug.log`

Debug 日志 SHA-256：

`44dbc7bfc2cb14883c5d1e9978499ea9d5ffd648bf9c58af779c4cec93683c39`

Release 日志：`docs/native-validation/artifacts/2026-10-06-icc-mpet-resource-safety/icc-mpet-release.log`，SHA-256 `f2daf1b698aa6588b27ecb67292953855b3d0da19cf3e4c74cd8ec8605b191c4`。

数值门禁日志：`docs/native-validation/artifacts/2026-10-06-icc-mpet-resource-safety/native-numerics.log`，SHA-256 `fad1c0f04956bb3a8375fd94c5d7b593abf3870cd868bf097f1ea23221227b86`。

快速全量门禁日志：`docs/native-validation/artifacts/2026-10-06-icc-mpet-resource-safety/native-fast.log`，SHA-256 `bca59880e4047f1424ec92b4b5a0f81622934b86d8cec4d6f21a3cd0e0ce8629`。

## 未覆盖范围

本记录不证明完整 ICC profile class、rendering intent、BPC、gamut mapping、ColorSync、第三方 profile 逐码参照、所有 MPE 元素、HDR/EDR 或 LUTAnalyst 任意三维全局反求已经完成；这些范围继续保持未完成，Goal 不标记 complete。
