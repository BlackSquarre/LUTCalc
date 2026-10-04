# Assimilate 1D `.lut` 格式阶段验收

日期：2026-09-24。范围：纯 Swift 的 Assimilate 1D `.lut` 文本解析/写出子集；仅为 FULL-06 的局部进展。

## 来源与契约

- 旧 `js/lutformats.js` 的“Assimilate 1D (.lut)”预设只列 4,096 点。旧 `js/lut-lut.js` 写出 `LUT: 3 N`，随后依次写 R、G、B 各 N 行整数，码值为 `Math.round(sample × (N-1))`；旧解析还接受 `LUT: 1 N`，将一列数据作为公共 1D 通道。文件域为单位域。
- 新 `AssimilateLUTParser` 接受上述两种明确布局，单列读入复制到 RGB；三列按通道块而非交错行读取。仅接受 `2...16384` 点、每行一个有符号十进制整数及头前注释，码值限制在有符号 32 位正负最大值内。文件上限 2 MiB；缺头、截断、额外数据、无效 UTF-8、非整数、非有限值和不支持的布局返回分类错误。
- 新 `AssimilateLUTWriter` 从单位域、无标题、无 shaper 的 1D `CubeLUT` 写三通道块；舍入保留 JavaScript `Math.round` 的半值向正无穷取整，包括负半值。码值溢出与无法无损表达的元数据显式拒绝。整数文件本身的量化无法保留任意 Double 样本。

## 验证

先新增 `AssimilateLUTContractsTests.swift`，Release 定向构建因 `AssimilateLUTParser`/`AssimilateLUTWriter` 不存在而失败；实现和测试表达式修正后运行 `swift test --package-path Native/Packages/LUTKit -c release --filter AssimilateLUTContractsTests`，实际执行 6 项、0 失败。覆盖三块顺序、单通道复制、正负半值舍入、4,096 点预设往返、畸形输入与不可表达元数据。该测试过程编译了依赖目标，但未代替全包测试或真实软件导入。

## 边界

旧解析使用宽松的前缀数值识别、从行内搜索 `LUT:`，且跳过某些坏行；这些行为无法证明为规范兼容要求。新子集要求独立头行和完整整数行，不猜测其它厂商 `.lut` 方言或未知元数据。当前未接入原生文件选择/导出服务，未在 Assimilate 软件中导入，也未验证真机文件流程；FULL-06 保持未完成。

源码 SHA-256：旧 `js/lut-lut.js` 为 `b748b64109afa0c26b99811daaca1b48369ef1f88b7f19dff361bb0bf6e2be88`；`AssimilateLUT.swift` 为 `fe34a4f8b5d683eacc6aa8941d81fe99e0ff53e26b096d38a8d220672736d5c5`；`AssimilateLUTContractsTests.swift` 为 `821f59153768738e47ff14509a4c9ca974496de6233c0b3afc15ac4de88abbc8`。
