# 2026-10-06 ICC 系统 profile absolute linking

使用 macOS 系统 `Display P3.icc` 与 `sRGB Profile.icc` 验证 absolute-colorimetric RGB matrix/TRC 路径。与 relative intent 的白点不匹配拒绝不同，absolute 路径按两个 profile 的 media white point 比例继续执行，输出保持有限并落在 `[-4, 4]` 的保护范围内。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests
```

结果：38 项通过，0 失败。该测试是结构和有限性证据，不是 ColorSync 或第三方软件逐码参照；BPC、gamut mapping 及完整 absolute intent 组合仍未完成。
