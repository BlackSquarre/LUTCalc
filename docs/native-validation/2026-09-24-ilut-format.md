# `.ilut` DaVinci Resolve 1D 格式阶段验收

日期：2026-09-24。范围：纯 Swift 实现 DaVinci Resolve `.ilut` 固定 14-bit 1D 文本子集；不代表 `.olut`、目标软件导入或 FULL-06 完成。

## 实现与边界

- `ILUTParser` 严格读取 16,384 行，每行四个逗号分隔整数；前三列是 RGB 14-bit 码值，第四列必须为旧格式固定的 `0`。
- `ILUTWriter` 仅接受单位域、16,384 节点、无标题/整形器的 1D `CubeLUT`，按 half-up 量化写出 `0...16383`，拒绝非有限、负值、超白及不可表示域。
- 使用 `Double` 保存归一化样本；不将格式量化误称为无损。实现没有引入厂商 LUT、旧 `.labin` 或采样表。

## 先失败后通过的契约

先新增 `ILUTContractsTests.swift`，因 API 尚不存在而按预期编译失败；实现后 Debug 与 Release 定向测试各 4 项通过，覆盖固定行数、逗号列数、第四列约束、非有限/小数/越界拒绝、half-up 边界和单位域拒绝。

Release 命令：`swift test --package-path Native/Packages/LUTKit -c release --filter ILUTContractsTests`；结果 4 项通过、0 失败。工具链 Apple Swift 6.4、arm64 macOS、Xcode 27.0。

## App 接线阶段

`.ilut` 现已接入原生文档导出草稿：格式选择器提供 `ILUT Resolve 14-bit 1D`，`NativeExportService` 按 `.ilut` 扩展名建立固定 16,384 点 1D 请求，`FileILUTSink` 先在暂存文件中完成 `ILUTWriter` 严格量化与大小校验，再执行原子提交。导出要求单位输入域和同色域计划；负值、超白、跨色域、默认覆盖和取消都会在提交前失败并清理暂存文件。

先失败后通过的接线契约位于 `ILUTServiceContractsTests.swift` 与 `ILUTExportContractsTests.swift`，覆盖文档会话导出、固定节点读回、不可表示请求拒绝、既有目标保护和量化失败清理。测试首先因 `FileILUTSink` 尚不存在而编译失败；实现后曾发现线性同色域链路在矩阵往返后产生极小域外值，严格 writer 按契约拒绝，因此成功用例采用输出范围可表示的 D-Log2 曲线，线性超范围作为拒绝用例保留。

`swift build --package-path Native/Packages/LUTKit -c release` 通过；`swift test --package-path Native/Packages/LUTKit --filter 'ILUT(Service|Export)ContractsTests'` 与同命令增加 `-c release` 均为 3 项通过、0 失败。期间并行新增的 Assimilate 测试曾因缺少 `try` 阻断全包编译，其作者修复后复测通过。

## 未完成

尚未在 Resolve 或其他目标软件导入，未验证厂商真实文件的注释/变体及 `.olut` 4,096 行方言；FULL-06 保持未勾选。完整发布门槛、真机和文件提供者流程也未因本子集改变。格式固有 14-bit 量化仍是有损表示，不宣称与 Double 样本无损等价。

## 源码指纹

- `Native/Packages/LUTKit/Sources/LUTFormats/ILUT.swift`：`525ca1da3c404aa3370a6651c5af23277ecfaf61d2e8fb112ec72d7fe5b81c5b`
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/ILUTContractsTests.swift`：`4a3d70942ca4bf563eecfe81b4d02afed7b64b224ab2e5f0a8b453220093ff89`
