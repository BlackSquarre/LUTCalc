# `.vlt` Varicam 3D 格式子集阶段验收

日期：2026-09-24。范围：FULL-06 的 Panasonic Varicam `.vlt` 3D 文本子集；不代表 `.vlt` 全兼容、App 接线或完整迁移。

## 来源与冻结边界

- 旧源码 `js/lut-vlt.js` 的写出使用 `LUT_3D_SIZE`、12-bit 码值 `0...4095`，并按输入缓冲的共享网格顺序写三通道；解析器将文本三通道除以 4095，允许 1D/3D 和多个输入范围。
- 本阶段只实现明确的 Varicam 3D `17³` 文件：固定头 `# panasonic vlt file version 1.0`、空 source 头、`LUT_3D_SIZE 17`，每行恰好三个十进制整数码值。内部始终使用 `Double` 的 unit 域和共享 R-fast 节点索引。
- 不猜测尺寸、输入范围或 1D 变体；标题、非 17³ 尺寸、非整数/非有限/越界码值和行数不符均拒绝。写出对负值、超白、非单位域、shaper 或标题返回 `lossyRepresentation`，不复刻旧实现的静默裁剪。

## 契约先行与结果

先新增 `VLTContractsTests.swift`，在 `VLTParser`/`VLTWriter` 尚不存在时编译失败；实现后修正测试表达式并运行：

`swift test --package-path Native/Packages/LUTKit --filter VLTContractsTests`

结果：4 项通过，0 失败。覆盖非对称 17³ 节点的红轴最快定位、12-bit 半码值 half-up 量化、写出再读回、缺行/多行、NaN、越界码值、非法尺寸/头部、损失性样本和非单位域拒绝。

## 修改与来源哈希

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTFormats/VLT.swift` | `6f54a4c61d16e1aa4304d0c6e39fe4306f94b71f59629ec3d83311280820fa7e` |
| `Native/Packages/LUTKit/Tests/LUTFormatsTests/VLTContractsTests.swift` | `62353376d26045105395b9ad03f32753a05d134b441a24efa6cb19e1a5ddfaa0` |
| `js/lut-vlt.js`（只读来源） | `f2d42576f50a3e3eeee19b917499c232bb47d6fb9ad8bf967611d2d561a1be7c` |
| `js/lutformats.js`（只读尺寸/能力来源） | `f197be83d3071f927ff682be9970b4efdddb94e8eddea11b466df14118c46dab` |

## 未完成项

本段未把 `.vlt` 加入 App 格式注册、导出服务或流式文件 sink，未做 33³/65³、Varicam 设备、第三方软件导入回读和真机保存。`.vlt` 的 1D/可变尺寸/输入范围方言仍待分别建立资料和契约；FULL-06、FLOW-02/03 继续保持未完成。
