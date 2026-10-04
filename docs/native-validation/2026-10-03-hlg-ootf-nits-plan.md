# 2026-10-03 HLG OOTF nits 计划归一化验收

## 范围

本阶段只处理非 UI `TransformPlan` 的 HLG OOTF nits 单位边界。stage 130 是显式显示亮度阶段，继续保留 `HLGOOTF.Scale.nits` 的绝对单位；stage 13 调用 HLG OETF 前才把 nits 乘以 `0.001`。post-gamma 的 `secondaryScene` 编码旁路使用同一规则。没有执行 UI、Finder/Files、iPadOS、实体设备、屏幕 HDR/EDR 或签名发布。

## 契约先行

先修改契约测试，要求 HLG 输出接受 `.nits`，PQ 输出仍抛出 `invalidHLGOOTFTransfer`，stage 130 的 scene `0.18` 保留 `6.476039825649833`，而 stage 13 等于 `HLGTransfer.encodeSceneToData(6.476039825649833 / 1000)`。实现前定向命令预期红灯，实际失败为 `invalidHLGOOTFScale`；未把红灯结果当作验收。

## 实现与工具链

- `TransformSettings.validateParameterizedTransfers()` 继续强制 HLG OOTF 只和 `.rec2100HLG` 输出组合，但同时允许 `.nits` 和 `.normalizedBy1000`。
- `TransformPlan` 的 stage 13 以及 post-gamma secondaryScene 路径在 HLG OETF 边界统一转换 nits；其他输出 transfer 不改变既有 `Double` 路径、网格、插值和阈值。
- 工具链：Xcode 27.0、Swift 6 语言模式、macOS 14 arm64。

## 实际结果

定向 Debug：

```sh
swift test --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
```

结果：8 项执行、0 失败。

定向 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
```

结果：8 项执行、0 失败。

完整回归：

```sh
swift test --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包共执行 546 项、0 失败；LUTFormats 的既有 `.labin` 与 NCP 外部夹具各 1 项跳过，命令退出码 0。完整日志：`/tmp/lutcalc-hlg-nits-full-20261003-r2.log`。

## 数值参照

- stage 130 默认 1000 nit、输入 scene `0.18`：`6.476039825649833` nit。
- 独立 80 位 Decimal 计算的 HLG OETF（`sqrt(3 * (6.476039825649833 / 1000))`）为 `0.13938478925962294182830785099662158133926920804326417294866668484193683511068286`。
- Swift stage 13 输出与该独立参照的绝对误差为 `1.83e-18`；契约阈值保持 `2e-14`，未放宽。

## 未完成范围

这只闭合 nits 计划的单位归一化子集。四种 HDR 显示变体、PQ/HLG 自动峰值／参考白／黑位准备、完整 HDR 限幅和裁剪统计、HDR/EDR 屏幕、ICC 完整类型、格式与目标软件互操作、文件提供商故障、性能预算、签名发布和真实 `full-scope-acceptance.json` 仍未完成。FULL-03/FULL-04 以及 Goal 保持 active。
