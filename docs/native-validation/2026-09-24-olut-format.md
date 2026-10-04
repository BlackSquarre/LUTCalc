# `.olut` DaVinci Resolve 1D 格式阶段验收

日期：2026-09-24。范围：纯 Swift 的固定 4,096 点、12-bit 六列整数文本子集；仅为 FULL-06 的局部进展。

## 契约和实现

- 先新增 `OLUTContractsTests.swift`，Release 定向执行因 `OLUTParser` / `OLUTWriter` 尚不存在而按预期编译失败；随后实现 `OLUT.swift`。
- 每行六个逗号分隔整数，后三列必须与前三列逐项相同。解析器要求恰好 4,096 个有效数据行，RGB 码值均在 `0...4095`，拒绝非有限、小数、越界、重复列不一致及超限文件；样本以 `Double` 归一化。
- 写出器仅接受单位域、无标题与整形器的 4,096 点 1D LUT，按 half-up 量化并复制 RGB 三列；超出 `0...1` 的结果显式拒绝。12-bit 文件量化是格式本身的限制，不改变生成时的 `Double` 精度。

## 旧版偏差

旧 `js/lutformats.js` 将 `.olut` 声明为 4,096 点；`js/lut-davinci.js` 的 `.olut` 写出乘以 `16383`，读回却除以 `4095`。同一文件无法按旧实现正确往返，且写出码值可超出 12-bit。本子集采用预设尺寸与读回标度一致的 `0...4095` 契约，不将这一旧偏差当作正确预期。目标软件真实导入仍需单独验证。

## 验证和范围

`swift build --package-path Native/Packages/LUTKit -c release --target LUTFormats` 已通过；`swift test --package-path Native/Packages/LUTKit -c release --filter OLUTContractsTests` 实际执行 4 项、0 失败。首次重试曾受并行中的 `.ilut` 导出测试 `await` 断言编译错误影响；该测试修正后重跑通过。全包回归待本轮其余格式接线结束后执行。未接入 App 导出服务，未验证 DaVinci Resolve 导入、真实厂商文件变体、真机或 File Provider；FULL-06 和发布门槛仍未完成。

源码 SHA-256：`OLUT.swift` 为 `6edc1ca0eb5294b171df275db1f592009dd363d4bf80fb320c15ac2c2c9dcd5e`，`OLUTContractsTests.swift` 为 `070a0aeeb1ed67eb7bfc4beeea7af992d6c99424774b02fe1771d60a9fb34002`，旧 `js/lut-davinci.js` 为 `e1a296035cbe83d0f94ffc84261c5ddc9b7879e57b2f0b522a0f14915836f592`。
