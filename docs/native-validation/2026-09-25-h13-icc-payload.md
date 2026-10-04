# H13 ICC tag payload 只读语义阶段验收

日期：2026-09-25。Goal 仍 active；本阶段只增加 ICC metadata-only 语义摘要，不执行显示/工作空间转换。

## 范围

- `text`、`desc`、`mluc` payload 读取为只读 `textValue`；其他 tag 只保留 type、偏移和字节数。
- 每个 tag payload 必须至少包含 ICC 四字节 type signature 和四字节 reserved 固定头；共享 payload 范围仍允许，不按重叠拒绝真实 profile。
- `text`/`desc` 仅接受 ASCII；`desc` 要求长度字段和末尾 NUL；`mluc` 要求 12 字节记录、偶数长度且 UTF-16BE 可解码。
- 不保存采样表，不实现 `curv`/`mft1`/`mft2`/`mAB`/`mBA` 求值，不做矩阵、白点适应、HDR/EDR 或 Core Image 色彩转换。

## 先失败后通过

最初多 tag 契约在测试夹具构造阶段崩溃，原因是测试辅助函数把大于 255 的 `UInt32` 偏移直接转换为 `UInt8`，触发 Swift `Not enough bits to represent the passed value`。修正为 `UInt8(truncatingIfNeeded:)` 后，随后增加的短固定头和畸形 UTF-16 契约均按预期拒绝。

定向命令：

```text
swift test --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：7 项通过，0 失败。

Release 定向命令：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：7 项通过，0 失败。

## 真实图像夹具

```text
python3 tools/native-validation/generate-preview-fixtures.py <临时目录>
sips -s format jpeg <临时目录>/rgb8.png --out <临时目录>/rgb8.jpeg
swift run -c release --package-path Native/Packages/LUTKit \
  LUTImageChecks <临时目录>
```

结果：退出码 0。真实 macOS sRGB profile 的共享 `curv` payload 范围通过；PNG 8/16 位、嵌入 ICC 原始字节、无嵌入 ICC 来源、TIFF/JPEG、方向 1–8、预乘 alpha、资源预算及符号链接拒绝均通过。

## 批量 Release 回归

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash tools/native-validation/verify-native-release.sh
```

日志：`/tmp/lutcalc-h13-icc-payload-release-20260925-rerun.log`

日志 SHA-256：`3fce335b0059f62ebcf3f4573b27b705f2204d9fb47862f95feedc5018a7a8d1`

`swift test --list-tests`：160 项；Swift Release XCTest 0 失败。旧 Node/Python 契约、macOS Release、iOS Simulator Release、iOS generic Release 和三个 App 包资源审计均通过。发布入口退出码 2，直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；没有伪造该清单。

## 未完成边界

ICC 完整 tag 类型覆盖、显示/工作空间色彩管理、整图显示、HDR/EDR、双端运行、Files/File Provider 独立读回/取消、剩余真机项目和 H01–H14 全量验收仍未完成。本阶段不改变 Double 计算、冻结精度门槛或既有批量生成结果。
