# `.spi1d` 格式阶段验收

日期：2026-09-24。范围：FULL-06 中 `.spi1d` 的共享 Swift 格式内核；此项不代表 FULL-06 或 H04 完成。

## 来源与版本

- 公开格式参照：[OpenColorIO `FileFormatSpi1D.cpp`](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/93878f9a8630081a6e8d866acf9fd119400c7a4e/src/OpenColorIO/fileformats/FileFormatSpi1D.cpp)，读取时确认远端 `HEAD` 为 `93878f9a8630081a6e8d866acf9fd119400c7a4e`。格式版本 1、可选 `From` 默认为 0–1、`Length`、`Components` 与数据花括号均据此确定。一个分量复制到 RGB；两个分量映射 R/G 且 B 为 0；三个分量逐通道映射。
- 旧实现 `js/lut-spi1d.js` SHA-256：`d675547f34bff65648ffbb2fd7498dc9a1f9d7d7ff455bb26cd693e73cacafbb`，仅用于风险定位。旧解析器的 2/3 分量分支未把结果返回给调用者，旧写出在非 ASC CDL 情况仅写第一个通道；原生实现没有复制这两个行为。
- 初次 Release 回归时源码 `Native/Packages/LUTKit/Sources/LUTFormats/SPI1D.swift` SHA-256：`f08012ead3e3c09a8c23d534492ceae6800495cf6142c31a4203c07a12274ce8`；契约测试 SHA-256：`7245742d1054fa9d112e6f340ddac080c7b2a0f6ad56624dbaa36ed275e2cc95`。后续同日新增标题无损性契约及共享数值词法入口，当前文件哈希见下文。

## 测试先行与结果

先添加测试并执行 `swift test --filter SPI1DContractsTests`，因 `SPI1DParser`、`SPI1DWriter` 尚不存在而编译失败；原始日志 `/tmp/lutcalc-spi1d-red-20260924.log`。实现纯 Swift 解析、格式模型和写出后，同一命令 6 项通过，0 失败；日志 `/tmp/lutcalc-spi1d-green-20260924.log`。工具链 Apple Swift 6.4、Xcode 27.0。

覆盖内容：1/2/3 分量映射、`From` 缺省与扩展域、Double 的逐通道位型往返（含负零）、现有 1D 线性插值和域外拒绝、1/2 分量导出的无损条件、非统一域拒绝、版本/重复字段/维度/行数/非有限值/尾随内容，以及超大 `Length` 在分配前拒绝。解析保留 `Components` 元数据；写出完整 RGB 时默认使用三个分量，不会静默丢失通道。资源上限沿用 CUBE 的 64 MiB 解码样本预算。

随后实际执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-spi1d-release-20260924.log`：旧 Node 9 项、App 包审计 Python 3 项、Swift Release XCTest 40 项均通过；macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`，三个实际 App 包资源审计通过。整个发布入口退出码仍为 2，明确缺少 `docs/native-validation/full-scope-acceptance.json`；该清单需要全量功能和平台证据，不以当前子集补造。

与 `.spi3d` 共用严格数值词法时，补入标题不可表示契约：测试先失败，修复后 `swift test --filter 'SPI[13]DContractsTests'` 共 11 项通过，日志 `/tmp/lutcalc-spi-metadata-red-20260924.log`、`/tmp/lutcalc-spi-metadata-green-20260924.log`。当前 `SPI1D.swift` SHA-256：`691f1d3bf39b6f4d864c2833f65d73cc36d07c7948002fa5cad04146b485395a`；`SPI1DContractsTests.swift` SHA-256：`b3fd8c272955aee89a158423d62e5ffca20cb532003d47d24ccd4b09978fe225`。初次 40 项/三个 App 构建的结果属于前一源码版本；最终源码的完整回归另记，不将它们混同。

上述最终源码已随 `.spi3d` 阶段重新通过 45 项 Swift Release XCTest 和三个 App Release 构建，详细命令与发布门槛结果见[`.spi3d` 格式阶段验收](2026-09-24-spi3d-format.md)。

## 边界

这一步只提供共享格式 API；App 的格式注册、文件选择与导出界面尚未接入 `.spi1d`，第三方目标软件的导入往返尚未验收。完整格式矩阵、其他 `.3dl`/`.spi3d` 等文件仍在 FULL-06 待办。当前测试的独立性来自公开格式代码的字段与通道定义；尚未取得第三方软件执行产生的逐点数值结果，故不宣称跨软件兼容验收。
