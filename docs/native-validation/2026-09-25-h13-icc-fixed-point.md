# H13 ICC 固定点 metadata 阶段验收

日期：2026-09-25。Goal 仍 active。本阶段继续保持 ICC 只读语义范围，不执行显示或工作空间转换。

## 契约先行

新增两个失败契约：

- `XYZ ` payload 解析为有符号 s15Fixed16 的 `Double` 摘要；
- `sig ` payload 解析为四字节签名；截断或非固定点长度必须拒绝。

首次定向编译按预期失败，因为 `ICCProfileTagValidation` 尚无 `fixedPointValues` 和 `signatureValue` 字段。实现后 `PreviewContractsTests` 的 10 项定向 Release 契约全部通过，包含 `text`、`desc`、`mluc`、`XYZ `、`sig `、短固定头、畸形 UTF-16、截断固定点 payload，以及 `mluc` 字符串不得覆盖记录表的边界。

命令：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：10 项通过，0 失败。

## 真实 sRGB ICC

`LUTImageChecks` 现在对系统生成的嵌入 sRGB profile 批量检查：

- `wtpt`、`bkpt`、`rXYZ`、`gXYZ`、`bXYZ`、`lumi` 等 `XYZ ` tag 都能得到有限 `Double` 摘要；
- `tech` 的 `sig ` 值读回为 `CRT `；
- 原始 profile 字节、SHA-256、共享 `curv` 范围和既有 PNG/TIFF/JPEG 数值契约保持通过。

命令：

```text
python3 tools/native-validation/generate-preview-fixtures.py <临时目录>
sips -s format jpeg <临时目录>/rgb8.png --out <临时目录>/rgb8.jpeg
swift run -c release --package-path Native/Packages/LUTKit \
  LUTImageChecks <临时目录>
```

结果：退出码 0。固定点摘要仅用于报告，未接入任何矩阵、白点适应、曲线求值或显示转换。

## 边界

`curv`、`mft1`、`mft2`、`mAB`、`mBA` 等采样或处理管线仍保持 opaque，不保存等价采样表。ICC v4、完整 tag 类型覆盖、显示/工作空间转换、整图显示、Core Image、HDR/EDR、双端运行和真机仍未完成。

## 集中回归

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash tools/native-validation/verify-native-release.sh
```

日志：`/tmp/lutcalc-h13-icc-mluc-boundary-release-20260925.log`

日志 SHA-256：`98614ded95b857a7cdae3693e9eed77a962f431e1a97132ec090e590af868a3c`

结果：退出码 2。`swift test --list-tests` 为 163 项，Swift Release XCTest、旧 Node/Python 契约、macOS/iOS Simulator/iOS generic Release 构建和三个 App 包资源审计通过；发布检查唯一直接失败项仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。
