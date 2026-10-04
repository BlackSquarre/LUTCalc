# 2026-09-27 系统 sRGB ICC 用户 profile 验收

## 范围

本阶段把 macOS 系统自带的 `/System/Library/ColorSync/Profiles/sRGB Profile.icc` 当作用户主动提供的真实 ICC 文件，验证原生 Swift `ICCProfileValidator` 和受限 `ICCMatrixTRCTransform` 能读取 RGB/XYZ、`rXYZ/gXYZ/bXYZ/wtpt`、真实 `rTRC/gTRC/bTRC`，并完成 Double 编码 RGB↔XYZ 往返。该 profile 未复制到仓库、未打入 App，也未作为内置转换资源。

这不是完整系统色彩管理验收；`mft1/mft2`、`mAB/mBA`、device-link、渲染意图、显示 profile linking、Core Image/EDR/HDR 与真实显示设备仍保持未完成。

## 契约测试

在 `ICCMatrixTRCContractsTests` 新增 `testSystemSRGBProfileLoadsThroughValidatedMatrixTRCPath`：

- 校验真实 profile 的 `RGB ` 色彩空间和 `XYZ ` PCS。
- 确认 `rTRC` 与 `rXYZ` 等必需标签存在。
- 对 `(0.5, 0.25, 0.75)` 执行编码 RGB→XYZ→编码 RGB。
- 三个通道往返误差门槛为 `2e-4`；XYZ 结果必须有限。

测试源码 SHA-256：`7f4ca22770258988ecfe74aefdeb105fc0b16af2f104cb0af3caaf4008085ae4`。

## 工具链与实际结果

- Xcode `27.0`（Build `27A266a`）。
- Apple Swift `6.4.0.34.1`，Swift 6。
- 系统夹具：`/System/Library/ColorSync/Profiles/sRGB Profile.icc`。

Debug：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests/testSystemSRGBProfileLoadsThroughValidatedMatrixTRCPath
```

退出码 `0`，1 项通过。日志 `/tmp/lutcalc-icc-system-srgb-debug-20260927.log`，SHA-256 `2b77408b878110c4e69ef8362842efdb9e8c60924d7decb3861b31feee3a5846`。

Release：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests/testSystemSRGBProfileLoadsThroughValidatedMatrixTRCPath
```

退出码 `0`，1 项通过。日志 `/tmp/lutcalc-icc-system-srgb-release-20260927.log`，SHA-256 `f93ead2f27b76501518c35baefe1c2dc3ae849115c569fe19585dcc3fb5d9a58`。

随后执行全包 Release 回归：

```text
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`，所有执行到的测试套件均为 0 失败。日志 `/tmp/lutcalc-icc-system-srgb-full-release-20260927.log`，SHA-256 `8b7472bffc7e17d369bcac70882f40822d11e235cb3665e516cea0356af797f8`。

## 结果边界

该证据加强了真实用户 ICC 文件读取和 CPU matrix/TRC 路径，但不改变 H13 的范围判断。完整 ICC、显示色彩管理、HDR/EDR、iPad 多窗口/旋转、Finder 直接双击重开、File Provider 故障、第三方软件往返、性能预算、发布签名和全量清单仍未通过；Goal 保持 active。
