# `.vlt` Varicam 17³ 文档导出接线验收

日期：2026-09-24。范围：将已验收的 Panasonic Varicam `.vlt` 17³ 子集接入原生文档草稿导出；不代表完整 `.vlt` 兼容或 FULL-06 完成。

## 契约先行

先新增 `VLTServiceContractsTests.swift`，分别约束文档会话产生可读回的 `.vlt` 分享文件，以及服务在目标文件创建前拒绝非 17³ 尺寸和非单位域。实现前运行：

`swift test --package-path Native/Packages/LUTKit -c release --filter VLTServiceContractsTests`

编译按预期失败于 `type 'FileLUTFormat' has no member 'vlt'`。测试夹具随后补上 `RGB64` 的 `try`，并选用可由严格写出器完整表示的 sRGB data 域恒等变换。

## 实现与结果

- `FileLUTFormat` 增加 `.vlt`；文档格式选择器增加 `VLT Varicam 17³` 和固定限制提示。现有 `NativeExportService` 按扩展名识别格式，文档会话继续使用原有 `GenerationCoordinator`。
- `FileCubeSink` 在创建目标前限定 17³ 和精确单位域，写入固定 VLT 头部和 R-fast 顺序的三通道整数行。`VLTWriter.row` 逐通道拒绝非有限、负值或超白值，采用 12-bit `0...4095` half-up 量化，不做静默裁剪。
- 文件仍沿用现有临时文件、顺序块、字节数验证、提交、失败清理和取消路径；本次没有改动事务或取消实现。

实现后运行：

`swift test --package-path Native/Packages/LUTKit -c release --filter VLTServiceContractsTests`

结果：2 项通过，0 失败。成功用例经文档会话导出后，用 `VLTParser` 读回 4913 个节点，并将代表节点与 `TransformPlan` 输出的 12-bit half-up 量化值逐通道比较。拒绝用例确认非法尺寸和非单位域均返回 `lossyRepresentation`，且目标文件不存在。

`swift build --package-path Native/Packages/LUTKit -c release --target LUTSharedUI` 和 `swift build --package-path Native/Packages/LUTKit -c release --target LUTFormats` 均成功。

## 文件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTFormats/VLT.swift` | `33d59d32fcc2810f483754fa9413c087c1f6270df3545be17ce9b9a32344e4aa` |
| `Native/Packages/LUTKit/Sources/LUTJobs/FileCubeSink.swift` | `6d6b7ed2b1eec85027333936ef22620775a68e5b981adbda53b6f15e35e9383c` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | `5a9dc68e3b3edbaba909915bf69931adf22c3bd566c4718801a3b9f99625b144` |
| `Native/Packages/LUTKit/Tests/LUTSharedUITests/VLTServiceContractsTests.swift` | `2b2d34533cc7ceef0329d47206ba133ab010ff7ba1e9ba58b84340995a865acb` |

## 未覆盖范围

未在 Varicam 设备或目标软件中验证导入，未在真机 Files/保存流程中验证；1D、可变尺寸、其他 VLT 方言和非单位域仍不支持。FULL-06 继续保持未完成。
