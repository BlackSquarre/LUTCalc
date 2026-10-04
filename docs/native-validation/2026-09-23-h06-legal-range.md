# H06 旧完整链 Legal 范围阶段对照

日期：2026-09-23。接续[旧完整无调节路径记录](2026-09-23-h06-legacy-full-path.md)，本步检查 DJI D-Log2/D-Gamut2、曝光 +1 档的四种 Data/Legal 输入输出组合。测试先固定完整旧引擎输出，再逐节点比较 Swift `TransformPlan` 的 Double 结果；旧引擎仅是兼容性参照，独立数学正确性仍由既有 DJI CTL、范围和矩阵夹具承担。

## 契约与修改

测试前，以 `--input-range Legal --output-range Legal` 调用旧夹具生成器，退出码 1，确认该范围尚未被覆盖。随后扩展研发专用 `generate-legacy-dlog2-exposure.js` 的范围参数，保持既有 Data→Data 文件名和内容；`verify-legacy-dlog2-exposure.js` 同时核对范围、曲线、色域、旧源码及二进制哈希。Swift `LUTContractChecks` 从同名 JSON 读取输入/输出范围与网格尺寸，逐通道按已有 `2e-12` 尺度化误差门槛比较。`verify-native-subset.sh` 纳入四组冻结 17³ 夹具。没有改变网格尺寸、位宽、插值或误差阈值。

修改文件：上述三份研发脚本、`Native/Packages/LUTKit/Sources/LUTContractChecks/main.swift`，以及三组新增的 17³ `.f64`/`.json` 测试夹具。旧 JS 源码、应用代码和 App 资源均未改动。研发旧引擎/夹具留在工具与测试路径，未进入 Native App。

## 实际命令和结果

以下命令均实际运行，退出码 0；每一组范围将 `Legal/Legal` 替换为 `Legal/Data`、`Data/Legal` 后也分别运行：

```text
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 17 --input-range Legal --output-range Legal
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outLegal.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outLegal.f64
swift build -c release --package-path Native/Packages/LUTKit
Native/Packages/LUTKit/.build/release/LUTContractChecks tests/fixtures/native-contracts/numeric-contracts.json tests/fixtures/dlog2-reference.json tests/fixtures/native-contracts/parser-contracts.json tests/fixtures/native-contracts/first-chain-reference.json tests/fixtures/native-contracts/srgb-reference.json tests/fixtures/native-contracts/srgb-legacy-reference.json tests/fixtures/native-contracts/srgb-plan-reference.json tests/fixtures/native-contracts/legacy-dlog2-exposure17-inLegal-outLegal.f64
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 33 --output-dir /tmp --input-range Legal --output-range Legal
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 65 --output-dir /tmp --input-range Legal --output-range Legal
tools/native-validation/verify-native-subset.sh
```

33³/65³ 的同名 `/tmp` JSON/Float64 文件还分别经 `verify-legacy-dlog2-exposure.js --metadata … --binary …` 与上述 Swift 可执行文件实际校验，均退出码 0。子集入口退出码 0，旧 JS 测试 9/9，静态扫描 35 个 Swift 源文件。这里的 17³ 是四种输入/输出组合；33³/65³ 本步只扩展 Legal→Legal。

| 网格 | 输入→输出 | 节点数 | 最大尺度化误差 | 最差节点 | 门槛 |
| --- | --- | ---: | ---: | ---: | ---: |
| 17³ | Data→Data（既有） | 4,913 | `1.9302615061889128e-13` | 4,657 | `2e-12` |
| 17³ | Legal→Legal | 4,913 | `8.813649962065352e-14` | 4,640 | `2e-12` |
| 17³ | Legal→Data | 4,913 | `7.548128788670283e-14` | 4,640 | `2e-12` |
| 17³ | Data→Legal | 4,913 | `2.254188589262407e-13` | 4,657 | `2e-12` |
| 33³ | Legal→Legal | 35,937 | `9.091053632875801e-14` | 34,879 | `2e-12` |
| 65³ | Legal→Legal | 274,625 | `9.466039063710241e-14` | 20,996 | `2e-12` |

## 可复现来源

SHA-256：生成器 `57c2f732da656df6a22e4ea03ae3143e2912ac055686fcc686410774c5c69190`；来源校验器 `dfc18d5c774cc57d2a9dad2e214f089a9d4fffa9beee1f38ad13d3560b495c9c`；Swift 契约入口 `f09df78c802ded6b578dc7a7c6afa6208737ec6d3182daf3718a4ddc404cd11e`；子集脚本 `16ab476bff9c5059f36b127da9a3b37a2a724d359423baa22fa395e14da064ea`。六份旧源码的逐文件哈希保存在各 JSON 中并由校验器与当前源码逐一比对。

| 夹具 | Float64 SHA-256 | JSON SHA-256 |
| --- | --- | --- |
| 17³ Legal→Legal | `9b9874dd1cf2e8fb0f5bd11e35f7d2441f78cc0e67be582f4d5aa81a3958144f` | `2e01f0bb4982fae89b2995f3d512bbab640c22831ad5839835dfa0613aab91df` |
| 17³ Legal→Data | `ab9bad6be087e9470dfa6863221352e298f5c6c4066be53e76a6b2998fe4e0f2` | `2b8cc89b5606c9b2593ecf7655eb41612283aed5e519682e83db1d939d42e0ba` |
| 17³ Data→Legal | `d103a963bf19be75618323b276a3c77c41bda6173644d1a871b8dc9e22bba7c6` | `2418196c9ada08927f241c3957bda2e34f5704d1cadf02529cfef4b48ce419bb` |
| 33³ Legal→Legal，`/tmp` | `389850e73f0fd3894f170a83bf361b4d965f9404520d48c6322b29e302672e3e` | `c61a0b1226180b7404a4be43e2a7a6f61a2928aa1228c0b47425313c54137a8f` |
| 65³ Legal→Legal，`/tmp` | `1ed1c44c5ef9547a4a1ccb914dfb5249dd3d46008ab6386979f419fac5a0dce0` | `6c2e7326bb9a47684daafb559a99fc756b208d849ec0b194da4aad4e18cd70b7` |

## 未覆盖及平台状态

本步没有覆盖 1D 旧完整链、调节/限制/False Colour、其他色域与格式，也没有证明旧版已确认缺陷应被复制。最大/RMS/P99 及故意扰动检出尚待 BASE-05。当前机器仍只有 Command Line Tools，没有 Xcode/iOS SDK；XCTest、两端 `.app`、模拟器、真机和发布检查仍未通过。H06/BASE-03/05 保持部分完成。
