# `.spi3d` 格式阶段验收

日期：2026-09-24。范围：FULL-06 中 `.spi3d` 的共享 Swift 格式内核；不代表 FULL-06 或 H04 完成。

## 来源与版本

- 公开格式参照：[OpenColorIO `FileFormatSpi3D.cpp`](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/93878f9a8630081a6e8d866acf9fd119400c7a4e/src/OpenColorIO/fileformats/FileFormatSpi3D.cpp)，本次读取的远端 `HEAD` 为 `93878f9a8630081a6e8d866acf9fd119400c7a4e`。其 `SPILUT 1.0`、`3 3`、统一三轴尺寸、三整数坐标加三输出值、蓝轴最快的行顺序与重复/越界拒绝作为格式参照。
- 旧实现 `js/lut-spi3d.js` SHA-256：`a1e0292b93a93b28c9cd2c2b759342031a3d30f1ae561852beeacfa7530a6438`。仅用于研发风险定位，不进入原生 App。
- 新源码 `Native/Packages/LUTKit/Sources/LUTFormats/SPI3D.swift` SHA-256：`098667a26d420d2b9a085f9f82b38457307ed8d4c80bc91a8e25fd9ea8cfb3ef`；契约测试 `Native/Packages/LUTKit/Tests/LUTFormatsTests/SPI3DContractsTests.swift` SHA-256：`a38eb385511cb4fb022cdf912f3b9fa05b7f7fee5a5d1efb35211a19ba4dfaf6`。使用共享 `SPI1DParser.number` 的严格十进制解析，仍全部为 Swift。

## 测试先行与结果

先添加契约并执行 `swift test --filter SPI3DContractsTests`，因尚无 `SPI3DParser`/`SPI3DWriter` 而编译失败；日志 `/tmp/lutcalc-spi3d-red-20260924.log`。实现后同一命令五项通过，0 失败；日志 `/tmp/lutcalc-spi3d-green-20260924.log`。随后为不可表示的标题与域中负零增加契约，`swift test --filter 'SPI[13]DContractsTests'` 先有三项失败；修复后两格式共 11 项通过、0 失败。日志 `/tmp/lutcalc-spi-metadata-red-20260924.log`、`/tmp/lutcalc-spi-metadata-green-20260924.log`。工具链 Xcode 27.0 / Apple Swift 6.4。

验证了文件蓝轴最快与内核红轴最快的明确映射，乱序行仍按坐标落位，身份 LUT 四面体插值在非对称点 `(0.25, 0.5, 0.75)` 三通道误差各不超过 `1e-15`；扩展 Double 值导出读回逐通道位型相同。重复、缺失、越界、非整数索引、错误版本/维度、非有限值、坏行和过大尺寸均拒绝；超大网格在分配前拒绝。格式没有输入域与标题字段，因此写出非单位域（包括负零）、标题、1D 或 shaper 数据会明确报无损表示错误。

## 边界

当前只提供共享格式 API；App 文件导入/导出入口、第三方软件真实读回、非统一三轴尺寸均未验收或不支持。OpenColorIO 参照代码自身暂不支持非统一三轴尺寸。本阶段的五项测试和两格式合并 11 项测试不等于双端 App 构建或发布通过；最终源码的完整回归结果另补记。

最终源码随后实际执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-spi3d-release-20260924.log`：旧 Node 9 项、App 包审计 Python 3 项、Swift Release XCTest 45 项均通过；macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`，三个实际 App 包资源审计通过。发布入口仍以退出码 2 报告缺少 `docs/native-validation/full-scope-acceptance.json`，未把子集结果当作全量发布通过。

后续已在同一日期增加 SPI3D 流式生成和草稿导出；本页源码哈希与“仅提供格式 API”的描述是**本阶段快照**，后续版本与实际回归见[流式导出阶段验收](2026-09-24-spi3d-stream-export.md)。
