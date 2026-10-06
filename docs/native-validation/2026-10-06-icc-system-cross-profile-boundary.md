# 2026-10-06 ICC 系统 profile 跨 profile 白点边界

使用 macOS 系统 `Display P3.icc` 与 `sRGB Profile.icc` 进行真实 linking 验证。两者的 PCS media white point 不一致，relative-colorimetric RGB matrix 路由明确返回 `matrix.mismatchedPCSWhitePoint`，不猜测白点适应。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests
```

结果：37 项通过，0 失败。该结果确认真实系统 profile 的拒绝语义与 synthetic 白点契约一致；absolute-colorimetric 的真实跨白点数值参照和 ColorSync 对照仍未完成。
