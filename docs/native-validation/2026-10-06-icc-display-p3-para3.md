# 2026-10-06 ICC Display P3 与 para type 3 验收

## 发现与修复

macOS 系统 profile `/System/Library/ColorSync/Profiles/Display P3.icc` 使用合法的 `para` parametricCurveType function 3。原实现把 function 3 错误解析为六参数并按带线性低段的形式执行，导致真实 profile 被拒绝。

按 ICC.1 parametric curve 定义修正为五参数 `g、a、b、c、d`：输入小于 `d` 时输出为零，输入不小于 `d` 时执行 `(a*x+b)^g+c`。逆向路径对零值平台报告非唯一，对高段执行闭式逆。

## 契约与结果

新增真实系统 profile 契约：

- `ICCMatrixTRCContractsTests.testSystemDisplayP3ProfileLoadsThroughValidatedMatrixTRCPath`
- `ICCRGBProfileLinkContractsTests.testSystemDisplayP3ProfileUsesExplicitMatrixRoute`
- `ICCMatrixTRCContractsTests` 与 `ICCRGBProfileLinkContractsTests` Release 定向合计 58 项，0 失败。
- 结果覆盖 Display P3 的 `mluc` 描述、`para` type 3、XYZ 原色、Matrix/TRC 编解码和同 profile relative-colorimetric linking。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'ICCMatrixTRCContractsTests|ICCRGBProfileLinkContractsTests'
```

## 未覆盖范围

该修复只关闭 `para` type 3 和 Display P3 matrix/TRC 真实 profile 子集；真实第三方 profile 逐码 ColorSync 参照、其他 profile class/intent、BPC、gamut mapping、ColorSync 全部语义、MPE 厂商扩展和完整 ICC 仍未完成。
