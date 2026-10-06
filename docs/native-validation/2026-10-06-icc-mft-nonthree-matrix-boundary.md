# ICC mft 非三通道矩阵边界验收

## 范围

`mft1/mft2` 标签只携带 3×3 矩阵。此前原生解析器在输入通道数不是 3、profile header 为 `XYZ ` 时仍接受非恒等矩阵，随后又不执行该矩阵，造成声明参数被静默丢弃。本项收紧为：非三通道设备数组只能使用恒等矩阵；合法三通道 RGB/PCS 路径和非三通道恒等 CLUT 路径不变。

## 契约与实现

先行失败契约 `testMFT2RejectsNonIdentityMatrixForNonThreeChannelPCSInput` 使用四输入通道、`XYZ ` header 和非恒等矩阵，旧实现未抛出错误。修复后初始化返回 `ICCMFTError.malformedTable`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests
git diff --check
```

红测日志：`/tmp/icc-mft-red-20261006.log`；修复后日志：`/tmp/icc-mft-green-20261006.log`。修复后 `ICCMFTContractsTests` Release 全部通过，退出码 `0`；差异检查退出码 `0`。

## 未覆盖

本项不扩展 ICC profile class、rendering intent、BPC、gamut mapping、ColorSync、`.labin` 或直接查表替代，也不代表完整第三方 profile 逐码参照完成。
