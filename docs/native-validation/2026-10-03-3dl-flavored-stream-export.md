# `.3dl` Lustre/Kodak 流式导出验收

日期：2026-10-03

## 范围

本轮只处理非 UI 的 `.3dl` 流式导出。解析器此前已经支持严格 Lustre 子集和纯整数 Kodak 子集；本轮将该 flavor 接入 `FileCubeSink`，并通过 `NativeExportService` 提供显式选择。现有 `.threeDL` 调用仍使用 Flame 语法。

Lustre 写出固定使用 `inputBits=10`、`outputBits=12`，网格尺寸限于 `9/17/33/65`（对应 `Mesh 3...7`），并在全部节点写入后追加 `LUT8` 与 `gamma 1.0`。Kodak 写出使用无厂商标记的整数行布局，保持与兼容 Flame 行语法相同的字节表示。所有通道仍由 `Double` 量化到 12-bit，未改变网格或插值规则。

## 契约先行

先增加 `ThreeDLExportContractsTests.testFlavoredStreamsWriteStrictLustreAndKodakGrammars`，在实现前运行得到预期编译失败：`FileCubeSink` 尚无 `threeDLFlavor` 参数。实现后新增 `ThreeDLServiceContractsTests.testNativeServiceSelectsLustreGrammarWithoutUI`，验证非 UI 服务入口可以选择 flavor。

## 实现

- `FileCubeSink` 增加公开 `threeDLFlavor`，默认 `.flame`。
- 头部由 `ThreeDLWriter.header(..., flavor:)` 生成，Lustre 写出 `3DMESH`、Mesh 规格与均匀 shaper。
- `validate` 在 Lustre 节点写完后按固定偏移追加 `LUT8\ngamma 1.0`，再执行字节数校验和提交。
- `NativeExportService.generate(..., threeDLFlavor:)` 暴露显式非 UI 入口；原有 `generate(_:to:)` 保持 Flame 默认。
- 写入仍经临时文件、顺序 block、目标指纹和原子提交路径；超域、越界通道、取消及默认覆盖保护保持原契约。

## 实际命令与结果

工具链：Xcode 27.0、Swift 6.4、macOS arm64，Swift Package `Native/Packages/LUTKit`。

```text
swift test --package-path Native/Packages/LUTKit --filter ThreeDLExportContractsTests/testFlavoredStreamsWriteStrictLustreAndKodakGrammars
```

结果：1 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit --filter 'ThreeDLExportContractsTests|ThreeDLServiceContractsTests'
```

结果：7 项通过，0 失败；已有 Flame、取消、覆盖和域错误契约保持通过。编译仅有既存的 `UnnecessaryEffectMarker` 警告。

```text
swift test --package-path Native/Packages/LUTKit
```

结果：完整 Swift 回归共执行 542 项，退出码 0；日志 `/tmp/lutcalc-3dl-flavored-stream-full-20261003.log`，SHA-256 `ae5edbc03d07209cba9bc25d1772375a793cc72c8d0a66fbae35c3acaffc1db8`。各测试包均为 0 失败；旧 `.labin` 夹具和 NCP 公共 specimen 各跳过 1 项，原因仍是环境未提供外部夹具。

## 独立读回与误差

- Lustre `9^3=729` 节点分两块写出，读取后由 `ThreeDLParser.parse(..., flavor: .lustre)` 通过严格头部、shaper、尾部和行数检查；端点通道读回为 `0` 与 `1`，量化误差由 12-bit 表示决定。
- Kodak `2^3=8` 节点写出后由 `ThreeDLParser.parse(..., flavor: .kodak)` 通过；产物不含 `3DMESH` 标记。
- 本轮没有引入厂商 LUT、采样资源或非 `Double` 计算，也没有进行第三方软件互操作测试。

## 未覆盖范围

Release 定向命令 `swift test -c release --package-path Native/Packages/LUTKit --filter 'ThreeDLExportContractsTests|ThreeDLServiceContractsTests'` 通过 7 项、0 失败；日志 `/tmp/lutcalc-3dl-flavored-stream-release-20261003.log`，SHA-256 `6d5bb87cb19e9a0d8ada6132bec9231d2e55955d44f7cbaa72a6dbe87cb1c585`。

完整 FULL-06 仍未完成：非线性 shaper、其他设备布局、NCP 写出、所有参数组合、真实目标调色软件往返以及 iCloud/File Provider 和 UI 交互仍待后续验收。真实全量验收清单仍缺失，Goal 保持 active。
