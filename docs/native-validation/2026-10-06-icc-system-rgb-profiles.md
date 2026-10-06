# 2026-10-06 ICC 系统 RGB profile 复验

在修正 `para` function 3 后，使用 macOS 系统自带 profile 复验 Matrix/TRC 路径：

- `/System/Library/ColorSync/Profiles/sRGB Profile.icc`
- `/System/Library/ColorSync/Profiles/Display P3.icc`
- `/System/Library/ColorSync/Profiles/AdobeRGB1998.icc`
- `/System/Library/ColorSync/Profiles/ITU-2020.icc`

每个 profile 均验证 `RGB ` 到 `XYZ ` 的头字段、Matrix/TRC 解码、有限 XYZ 输出以及编码往返。Display P3 额外覆盖 `mluc` 描述和 `para` type 3 曲线。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests
```

结果：`ICCMatrixTRCContractsTests` 24 项通过，0 失败。该证据只覆盖系统 RGB matrix/TRC profile 的结构和数值往返，不代表全部 ICC profile class、rendering intent、BPC、gamut mapping、ColorSync 语义或真实第三方逐码参照已经完成。
