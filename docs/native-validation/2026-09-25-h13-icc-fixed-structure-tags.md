# H13 ICC 固定结构 tag metadata 阶段验收

日期：2026-09-25。Goal 仍 active。本阶段只增加 ICC 固定结构 tag 的只读摘要，不做颜色转换，不改变 CPU Double 路径、采样表或精度门槛。

## 可追溯定义与范围

本轮结构按公开 ICC profile 规范的 tag type 定义核对：

- ICC 官方规范入口：<https://www.color.org/icc_specs2.xalter>；当前规范 PDF 入口为 <https://www.color.org/specification/ICC.1-2022-05.pdf>。
- 本机可复核的独立二进制定义位于 Shutter Encoder 随附 ExifTool `ICC_Profile.pm`：`ViewingConditions`（`view`）8/20/32 字节、`Measurement`（`meas`）8/12/24/28/32 字节、`Chromaticity`（`chrm`）8/10/12 起始布局。该文件同时把这些类型列为 ICC 固定结构类型；没有把采样型 `curv`/LUT payload 当作可直接求值的颜色链。

实现摘要字段保持 metadata-only：

- `curv`：只报告 `structureValue` entry count，不保存曲线条目；count 与 payload 边界不匹配即拒绝。
- `chrm`：报告 `[channels, colorant]` 到 `integerValues`，按 ICC 每通道 x/y 两个无符号 16.16 fixed-point 值读到 `fixedPointValues`。
- `para`：报告 function type 到 `parametricFunctionType`，按 function type 0–4 读取规定数量的 s15Fixed16 参数；未知函数或截断参数拒绝。
- `view`：报告六个 XYZ s15Fixed16 到 `fixedPointValues`，保留末尾四字节 illuminant word 到 `integerValues`。
- `meas`：报告 backing XYZ 与 flare（u16Fixed16）到 `fixedPointValues`，保留 observer、geometry、illuminant 三个四字节 word 到 `integerValues`。

四字节 word 保留原始无符号值，避免把规范签名或厂商扩展误译成颜色空间。所有字段仅供检查和显示；代码没有矩阵、白点适应、曲线求值、显示空间转换或 LUT 采样表存储。

## 契约先行与定向验证

先加入两项 XCTest：固定结构 tag 的正常摘要，以及 `curv/chrm/para/view/meas` 的截断/边界拒绝。首轮构造编译暴露了测试 helper 的 `UInt16` 拼接和表达式类型检查问题；修正夹具构造后，所有实现边界均按预期通过，未放宽生产校验。

定向 Release 命令：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：`PreviewContractsTests` 12 项通过，0 失败。日志：`/tmp/lutcalc-h13-icc-fixed-structure-release-20260925.log`；SHA-256：`5f81d64227e1bca71479221740ce43bfb1c19c172aae6c541b516f0c428bf4ca`。

真实 macOS ImageIO 夹具的定向检查仍通过：

```text
python3 tools/native-validation/generate-preview-fixtures.py <临时目录>
sips -s format jpeg <临时目录>/rgb8.png --out <临时目录>/rgb8.jpeg
swift run -c release --package-path Native/Packages/LUTKit \
  LUTImageChecks <临时目录>
```

结果：退出码 0；既有 PNG/TIFF/JPEG 原始样本、嵌入 ICC 字节、共享 `curv` 范围、CRC、重复 `iCCP` 拒绝契约保持通过。

## 边界与后续

本轮没有运行全量发布门槛，没有生成或修改 `full-scope-acceptance.json`，没有做真机工作。ICC 完整 tag 类型覆盖、`curv`/LUT 求值、显示/工作空间转换、整图显示、Core Image、HDR/EDR、双端运行、Files/File Provider 和真机读回仍未完成；H13/UI-03 继续不勾选。

## 集中 Release 回归

固定结构 tag 接线后执行集中入口：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh
```

结果：`swift test --list-tests` 为 **167 项**；Swift Release XCTest、既有 Node/Python 契约、33³/65³ 批量生成与独立读回、macOS Release、iOS Simulator Release、iOS generic Release 和 3 个 App 包资源审计均通过。完整日志为 `/tmp/lutcalc-h13-fixed-structure-release-full.log`，SHA-256：`362db274dc63c2545ca436d83f4c26cb69a634d3649e4b2943ad6e82363534fb`。

发布入口退出码为 2，唯一直接拒绝项仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；本轮未创建占位清单。真机、Files/File Provider、完整 ICC 类型覆盖、显示/工作空间转换、整图显示、HDR/EDR 和完整 H13/UI-03 仍未验收。
