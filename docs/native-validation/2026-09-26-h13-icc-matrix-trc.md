# H13 ICC RGB 矩阵/TRC CPU 子集阶段验收

日期：2026-09-26

## 失败契约

现有 H13 ICC 代码只负责 profile 结构校验、来源 provenance 和只读摘要，不把 ICC payload 默认为可执行的显示色彩管理。本批先加入 `ICCMatrixTRCContractsTests`，要求一个独立的、明确受限的 RGB matrix/TRC CPU 计划；在类型不存在时定向编译必须失败。

失败契约要求：

- 只接受 ICC `RGB ` 色彩空间与 `XYZ ` PCS；其他空间必须拒绝；
- 必须存在 `rXYZ`、`gXYZ`、`bXYZ`、`wtpt`、`rTRC`、`gTRC`、`bTRC`；
- RGB→XYZ 必须显式经过 encoded RGB、TRC 解码、linear RGB、矩阵和 XYZ 阶段；
- XYZ→RGB 必须显式经过矩阵、linear RGB、TRC 编码和 encoded RGB 阶段；
- 仅接受可追溯的 `curv(count=1)`、`para(type=0)` 和 `para(type=4)`；其他曲线形式、非单位域输入和缺失标签必须拒绝；
- 不改变现有 `PreviewImageDecoder` 的默认 provenance 或显示映射，不把该子集称为完整 ICC 工作空间管理。

首次定向命令：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests
```

结果：按预期因 `ICCMatrixTRCTransform`、阶段类型和错误类型尚不存在而失败；随后才实现 Swift 代码。失败输出保留在本次会话日志中。

## Swift Double 实现

新增 `Native/Packages/LUTKit/Sources/LUTPreview/ICCMatrixTRCTransform.swift`：

- `ICCMatrixTRCTransform` 先调用既有 `ICCProfileValidator`，再从已验证的结构摘要构建 RGB 三列 XYZ 矩阵及逆矩阵；
- `curv(count=1)` 按 ICC u8Fixed8 gamma 解码；`para(type=0)` 支持纯 gamma，`para(type=4)` 支持分段参数曲线；其余类型明确拒绝；
- 记录 `profileWhitePoint`，但不隐式执行白点、显示器或工作空间转换；
- `ICCMatrixTRCTrace` 显式保存编码、解码、线性、矩阵和 XYZ 阶段，逆向同样保留编码阶段；
- `ICCProfileTagValidation` 增加受限 `curv` 曲线条目摘要，count=1 使用 u8Fixed8，采样曲线使用归一化 UInt16；不保存厂商 LUT 或原始采样表；
- 所有算法使用 Swift `Double` 和现有 `Matrix3x3`，不引入 Core Image、Metal、Web/JS runtime 或等价资源。

## 定向契约与数值门槛

`ICCMatrixTRCContractsTests` 共 5 项：

1. 单位矩阵、gamma 2.0 的阶段顺序与独立 `pow` 参考；
2. `para(type=4)` 的独立分段参考；
3. 33³ 与 65³ 全网格 encoded RGB↔XYZ 往返，最大绝对误差门槛 `2e-12`；
4. 非 RGB、非 XYZ PCS 和缺少必需标签拒绝；
5. 不支持的 `para(type=2)` 与单位域外输入拒绝。

## 回归结果

- 定向 Release：5 项通过；
- 全量 Swift Release：`swift test -c release --package-path Native/Packages/LUTKit` 通过；`swift test --list-tests` 列出 235 项，LUTPreviewTests 29 项通过，既有公开 NCP 实样按设计跳过 1 项；
- `bash tools/native-validation/verify-native-subset.sh` 通过，既有 46 对 33³/65³ CUBE、H04/H08/H09/H10/H12/H13 命令行契约全部通过；
- `bash tools/native-validation/verify-native-release.sh` 的 Swift Release、macOS Release、iOS Simulator Release、iOS generic Release 和三个 App 包资源审计通过；
- 发布入口退出码仍为 `2`，唯一直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造清单。

## 证据 SHA-256

- `ICCMatrixTRCTransform.swift`：`69a310b3a0cbb73dc19f04eba0afc6319c6a3d930c7b7964b7dd21d7a76ca123`；
- `ICCProfile.swift`：`629730ca6777c4e6d2d1926f11c38aa64992907d2065ee84e31a1631d59821c8`；
- `ICCMatrixTRCContractsTests.swift`：`0d969011f9b09bda2437f0049fec9fa18c68258623d5b401022f377aca86d377`；
- 本验收记录正文（去除本哈希清单行）：`26f0db79c5bdee666532ee207cc3ecc7deefb9f892b22da7aad700b4b9250855`；
- 定向日志 `/tmp/lutcalc-icc-matrix-trc-targeted.log`：`2ebb6dce5b66feb004bfc9aea31db8632f59ea22e135f7e07fb58e776b797040`；
- 全量 Swift 日志 `/tmp/lutcalc-icc-matrix-trc-swift-full.log`：`38a99c7f6a8a9d4977c8caa6f4b1d78641f94fbb0098d90e7b8c3bb414eb999f`；
- 子集日志 `/tmp/lutcalc-icc-matrix-trc-subset.log`：`d9b1372f8aaf08702688e362d8cc7698d59d109a47c36fdaa3f3b98f6297fee2`；
- 发布入口日志 `/tmp/lutcalc-icc-matrix-trc-release.log`：`8fabc1a1fa52fb88197c8b63a276bbeab0245e6982e544ac2e495a5ee20feb5b`。

## 范围结论

本批只完成 ICC RGB matrix/TRC 的可追溯 CPU 子集和拒绝边界，不等于完整 ICC profile 类型覆盖、跨白点/显示工作空间管理、Core Image/Metal、HDR/EDR、整图显示、真机、Files/File Provider 或完整迁移。默认显示路径仍不因存在 ICC metadata 而隐式转换；H13、UI-03 和发布门槛继续未完成。
