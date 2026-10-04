# H13 预乘 alpha 显示位图量化阶段验收

日期：2026-09-25。Goal 仍 active。本阶段只收紧显示边界的 RGBA8 预乘 alpha 契约，不改变 Double 取样、LUT 生成、导出或 ICC 解释。

## 缺口与契约先行

`DisplayPreviewBitmap` 原来对 RGB 和 alpha 独立量化。若一个标记为 `.premultiplied` 的显示样本意外带有大于 alpha 的 RGB，生成的 RGBA8 可能出现 `RGB > A`，不再满足预乘像素布局。先加入 `PreviewContractsTests.testDisplayPreviewBitmapClampsPremultipliedChannelsToQuantizedAlpha`，预期 `[255, 128, 0, 26]` 与固定契约 `[26, 26, 0, 26]` 不一致，Release 定向测试按预期失败。

实现位于 `Native/Packages/LUTKit/Sources/LUTPreview/CPUPreview.swift`：先量化 alpha，再在 `.premultiplied` 分支把每个 RGB 字节钳制到 alpha 字节；`.straight` 保持原有独立量化。测试通过 `@testable import` 构造边界样本。真实 `CPUPreview.renderDisplay` 生成的有效样本数值不变。

## 定向 Release 验证

先失败：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter PreviewContractsTests.testDisplayPreviewBitmapClampsPremultipliedChannelsToQuantizedAlpha
```

退出码 1；失败差异为旧实现 `[255, 128, 0, 26]`、契约期望 `[26, 26, 0, 26]`。日志：`/tmp/lutcalc-h13-premul-alpha-red.log`，SHA-256：`305e75b18d81bba41f0e47eba5ce48037eb9f5e07906c543627fcdbda6a52ca2`。

实现后：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter PreviewContractsTests
```

退出码 0；`PreviewContractsTests` 23 项全部通过。日志：`/tmp/lutcalc-h13-premul-alpha-targeted.log`，SHA-256：`480394643bdc01ee9510323d39b1dc9e051619a55102f51245685e775aa151de`。

## 批量回归

```text
bash tools/native-validation/verify-native-subset.sh
```

退出码 0。原生子集静态检查、旧 Node/Python 契约、33³/65³ 批量 CUBE 生成与独立读回、H13 ImageIO 夹具、后台显示位图和 H08–H12 相关命令行契约均通过。日志：`/tmp/lutcalc-h13-premul-alpha-subset.log`，SHA-256：`f4441617f5bf069f6f0b3d7a70c965277e059cb2e1a100d68aedd3d030d4528d`。

本阶段没有运行或宣称完整发布门槛；完整 ICC 类型、真实显示色彩管理、HDR/EDR、其他像素布局、Files、真机和全量验收清单仍未完成，H13 不勾选。
