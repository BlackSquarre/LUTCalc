# 2026-10-02 HLG OOTF schema 22 与计划阶段验收

## 范围

本阶段只处理非 UI 的 HLG OOTF 接线：参数持久化、算法身份、项目 schema、严格旧版本拒绝、不可变设置复制和 `TransformPlan` 阶段追踪。没有执行 macOS/iPad/iPhone UI、Finder/Files、真机、屏幕 HDR/EDR 或签名发布。

HLG OOTF 数学来源和独立 Decimal 参照沿用[2026-10-02 HLG OOTF 数学阶段](2026-10-02-hlg-ootf.md)。产品实现仍只使用 Swift `Double`，不读取 JavaScript、厂商 LUT 或采样表。

## 实现

- `HLGOOTFSettings` 保存算法身份、输入/输出峰值、黑位、nits/归一化标度和 BBC 输入/输出系数，并可独立构造已验证的 `HLGOOTF` 内核。
- `TransformSettings` 增加可选 `hlgOOTF`，所有 `with...` 复制方法、Codable 和 `planVersion` 均保留该字段。
- 项目 schema 从 21 提升到 22；`algorithmVersions["hlgOOTF"]` 与参数身份严格匹配。schema 1–21 携带 `settings.hlgOOTF` 时拒绝，schema 22 对未知字段拒绝，旧项目没有该字段时保持原迁移行为。
- `TransformPlan` 增加显式阶段 ID `130`。它位于 scene 调节完成后、阶段 13 输出编码前，输出单位为 `displayLuminance`；当前只允许 HLG 输出和 `normalizedBy1000`，随后进入既有 HLG OETF。阶段 06/07 继续保留给未解决的白平衡/PSST。

## 契约与命令

先行定向命令：

```sh
swift test --package-path Native/Packages/LUTKit --filter 'HLGOOTF(Contracts|ProjectContracts)Tests'
```

结果：HLGOOTF 核心 6 项、项目 schema 1 项均通过，0 失败。

完整回归命令：

```sh
swift test --package-path Native/Packages/LUTKit
```

工具链：Xcode 27.0，Swift 6 语言模式，macOS 14 arm64 目标。初次接线完整回归执行 533 项，0 失败；修复文稿参数化 Gamma 编辑保留 OOTF 后，最终完整回归执行 **534 项**，0 失败；LUTFormats 的 2 项既有 `.labin`/NCP 外部夹具缺失跳过。最终日志：`/tmp/lutcalc-hlg-schema22-preservation-full.log`，命令外层退出码 `0`。

## 数值结果

- 默认 1000 nit、输出 BBC 系数、scene `0.18` 的 stage 130 归一化值：`0.02248224488944945`，契约误差阈值 `2e-14`。
- HLG OOTF 原数学阶段的典型值仍为：默认输出 `6.476039825649833...` nit；400 nit、BBC 启用输出 `15.256460622889294...` nit；RGB 前向/逆向往返阈值 `2e-12`。
- 本阶段没有生成完整 33³/65³ HLG OOTF 组合 CUBE，也没有把 nits 单位接入最终输出范围映射；因此不把本阶段计作完整 HDR 输出验收。

## 变更文件哈希

以下 SHA-256 对应本阶段验收时源码：

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTCore/HLGOOTF.swift` | `1d132cb9a6cfaddf77ed0ffd655de2975c7e936957246edf7f0898e7ae53e238` |
| `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift` | `ba93f121f3b01a7c79e8a59bb9d2ba930231cd797f0a8f165a4f1ac52ea83e16` |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` | `e33c1de47fa12995295678ac1937e017326ddc42f354f36d109f37c929d191f6` |
| `Native/Packages/LUTKit/Tests/LUTCoreTests/HLGOOTFContractsTests.swift` | `68ffd05e35d44b8de0df858f4dc7558b37e718759cf0f355212f07d45244fe84` |
| `Native/Packages/LUTKit/Tests/LUTProjectTests/HLGOOTFProjectContractsTests.swift` | `de3561ff4a392f0ea1487c85c79a4c9e939c724a7dcf394114a205f305c1454a` |

## 后续缺陷修复

发现 `LUTProjectDocument.applyParameterizedGamma` 手工重建 `TransformSettings` 时遗漏 `hlgOOTF`，会在已有 HLG OOTF 项目编辑输入/输出参数后丢失该设置。已补上字段传递，并新增文稿契约覆盖内存编辑和文件包装重开。

- 修复源码 `LUTProjectDocument.swift` SHA-256：`9b9164a37a9ecd7a294dae1501e009c68617c7cecf361a859bdfb34a209d18e5`。
- 新增契约源码 `ParameterizedGammaEditorContractsTests.swift` SHA-256：`231e763c0dbf45c0542981b9914d79c001236eb5e0fddfa4d174a0704571aedc`。
- 定向文稿/HLG/schema 测试为 3 + 1 + 6 项，全部通过；最终完整 Swift 回归为 534 项，0 失败，2 项既有夹具跳过。

## 未完成与限制

- 四种旧 HDR 显示变体、PQ OOTF、自动峰值/参考白/黑位准备、完整 HDR 限幅和裁剪统计仍未实现。
- nits 单位目前只在独立 `HLGOOTF` 数学内核中可用；计划组合会明确拒绝，避免把绝对亮度误当归一化 LUT 数据。
- 完整 33³/65³ 组合参照、Release 三平台构建、HDR/EDR 实屏、ICC 完整类型、目标软件往返、文件提供商故障和发布签名仍未验收。
- 真实 `docs/native-validation/full-scope-acceptance.json` 仍不存在；未创建或伪造该清单。Goal 保持 **active**。

## 2026-10-03 后续修复

本文件记录 2026-10-02 的阶段快照，当时 nits 计划组合仍被拒绝。2026-10-03 已由[HLG OOTF nits 计划验收](2026-10-03-hlg-ootf-nits-plan.md)补齐单位边界：计划允许 `.nits`，stage 130 保留 nits，stage 13 的 HLG OETF 前才除以 1000。上面 nits 拒绝描述仅保留为历史快照，当前状态以新验收记录为准；完整 HDR 显示单位链、自动峰值/参考白/黑位准备和输出范围映射仍未闭合。
