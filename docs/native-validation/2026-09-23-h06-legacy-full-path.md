# H06 旧完整无调节路径阶段对照

日期：2026-09-23。本次使用真正的旧版 `LUTGamma.inCalcRGB → LUTColourSpace.calc(g=true) → LUTGamma.outCalcRGB`，核对 Swift 无调节 D-Log2/D-Gamut2 → 曝光 +1 → D-Log2/D-Gamut2 的 17³、33³、65³ 节点。旧引擎与二进制夹具只在研发工具、测试目录和 `/tmp`，没有进入 App。

## 来源和契约

新增 `generate-legacy-dlog2-exposure.js`，在 Node `vm` 中加载旧 `lut.js`、`ring.js`、`bounding.js`、`brent.js`、`gamma.js`、`colourspace.js`，调用上述完整路径。固定输入/输出曲线与色域、Data 范围、曝光增益 2、R 最快网格顺序，逐通道写 little-endian Float64 原始数据与含六份旧源码 SHA-256 的元数据。新增 `verify-legacy-dlog2-exposure.js`，核对当前旧源码集合、每份源码哈希、元数据、尺寸和二进制哈希。Swift `LUTContractChecks` 按 little-endian 位模式读取旧样本，与独立创建的 `TransformPlan` 逐节点对照，保留原先 `2e-12` 尺度化误差门槛。它是一条**无调节**完整调用路径，不能代替所有旧功能与设置对照。

17³ 夹具保存在 `tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64` 与同名 JSON；33³/65³ 输出到 `/tmp`，可由脚本重现，避免把大文件打入应用资源。独立公式参照仍以既有 DJI CTL/NumPy 夹具为准；旧引擎本身用于兼容性比较，不被视为所有数值行为的正确真值。

## 实际运行与误差

先运行 `node tools/native-validation/generate-legacy-dlog2-exposure.js`，随后运行：

```text
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 33 --output-dir /tmp
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 65 --output-dir /tmp
node tools/native-validation/verify-legacy-dlog2-exposure.js
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata /tmp/legacy-dlog2-exposure33.json --binary /tmp/legacy-dlog2-exposure33.f64
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata /tmp/legacy-dlog2-exposure65.json --binary /tmp/legacy-dlog2-exposure65.f64
swift run -c release --package-path Native/Packages/LUTKit LUTContractChecks tests/fixtures/native-contracts/numeric-contracts.json tests/fixtures/dlog2-reference.json tests/fixtures/native-contracts/parser-contracts.json tests/fixtures/native-contracts/first-chain-reference.json tests/fixtures/native-contracts/srgb-reference.json tests/fixtures/native-contracts/srgb-legacy-reference.json tests/fixtures/native-contracts/srgb-plan-reference.json tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64
```

最后一条命令分别将末尾二进制路径改为 `/tmp/legacy-dlog2-exposure33.f64`、`/tmp/legacy-dlog2-exposure65.f64` 也实际执行并通过；17³ 的 Debug 执行同样通过。`tools/native-validation/verify-native-subset.sh` 已纳入冻结 17³ 来源校验与 Swift 对照，再次退出码 0。

| 尺寸 | Float64 RGB 节点 | 最大尺度化误差 | 最差节点 | 门槛 |
| --- | ---: | ---: | ---: | ---: |
| 17³ | 4,913 | `1.9302615061889128e-13` | 4,657 | `2e-12` |
| 33³ | 35,937 | `2.0775048348298242e-13` | 34,979 | `2e-12` |
| 65³ | 274,625 | `2.0775048348298242e-13` | 270,854 | `2e-12` |

研发源码/夹具 SHA-256：生成器 `b0ecbf2a093a6fb7f32805ecdbf64ba382d14436bdef1a4d3edbd02ed3a0a3e6`；来源校验器 `ab18a31ab3788729b3fd2ba49e82a3998f2851d63f792227efd1391c252a1c58`；`LUTContractChecks/main.swift` `6b17ee0196ac5dcee9cce8454a1329e110c4baa1e3189e73999e4537a6bedd4d`；17³ 二进制 `30eb1ec24358e804a633849d5b836be8b1c7c13025c646ea9fa2597e552c78b2`、元数据 `f422b6536660673464555524b879e07277be3e2a252ff5517426c8500cc34a3b`；33³ 二进制 `6e809c87ab82f6b669bac8b450f9d68bf5e58d68caac838162ccb85e695fa601`；65³ 二进制 `6fc646c5ba8311879a0abdda34557b2fe0dc1b794b754e3ce632f03b4f28d735`。六份旧源码的逐文件哈希在 17³ 元数据中；执行时核对当前文件。子集脚本现版 SHA-256 为 `7b2a817d5bcd0f6e655b2e3ec5db4a715635f9b7833647b093b0ea1a3d938653`。

## 平台与剩余范围

本机仍只有 Command Line Tools，XCTest、macOS/iOS `.app` 和真机均未通过。本对照尚缺输入/输出 legal、1D、完整调节/限制/False Colour、其他色域与格式，以及全阶段误差预算。旧版已确认的索引、解析、求根与非有限值缺陷不作为 Swift 正确行为复制。H06/BASE-03/05 仍仅部分完成，不能标为完整迁移。
