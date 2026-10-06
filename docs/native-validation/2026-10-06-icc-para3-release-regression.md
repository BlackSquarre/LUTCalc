# 2026-10-06 ICC para type 3 Release 回归

在修正 ICC parametricCurveType function 3 为规范五参数后，先运行 `PreviewContractsTests` 44 项，全部通过；随后运行完整 LUTKit SwiftPM Release 回归。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

结果：命令退出码 0，所有测试 target 通过。该回归确认真实 Display P3、AdobeRGB1998、ITU-2020 profile 解析修复没有破坏 LUTCore、LUTAnalysis、LUTProject、LUTFormats 或共享服务契约。
