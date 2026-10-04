# `.ncp` 写出研究阻塞记录

日期：2026-09-24。范围：FULL-06 的 Nikon Custom Picture `.ncp` 研究小包。当前仅确认旧版行为；没有冻结原生格式契约，没有实现 Swift 写出，也没有完成设备兼容验收。

## 来源与可确认范围

- 旧实现为 `js/lut-ncp.js`（SHA-256 `7fe9a89b4e87dbc4d951b1dca52eebb92b19f98031f028ca05d0105dbd3d3441`）。它只写出，不解析。文件头自述结构来自 NikonHacker 帖子 `https://nikonhacker.com/viewtopic.php?t=1803` 中 `coderat` 的建议；2026-09-24 访问原链接及 `www.nikonhacker.com` 均返回 HTTP 404，未能核验原帖内容。
- 旧预设 `js/lutformats.js`（SHA-256 `f197be83d3071f927ff682be9970b4efdddb94e8eddea11b466df14118c46dab`）将输出限定为 1D、256 点、legal 输入与输出，列出 Standard、Neutral、Vivid、Monochrome、Portrait、Landscape 六个 Nikon 风格。旧更新说明 `js/lutinfobox.js`（SHA-256 `3dc7caa2c817320da6f3b16ad10bc8b63281583db1afaae166383e993d9066fb`）称该支持为 Beta。
- [Nikon Picture Control Utility 2 官方导出帮助](https://www.nikonimglib.com/npcu/onlinehelp/en/pc013000.html)确认 NCP、NP2、NP3 是不同产品类型，存储卡可分别保存最多 99 个 Picture Controls，且应由兼容相机格式化；[官方导入帮助](https://www.nikonimglib.com/npcu/onlinehelp/en/pc012000.html)要求相机或软件兼容、基础可选 Picture Control 已安装。两页均未规定 NCP 二进制布局、量化规则或本项目所支持的具体机型。仓库现有 Nikon ZR 产品页不是这些问题的参照。
- 仓库内未找到 `.ncp` 实样、官方导出样本、独立解析器的读回结果或相机导入结果。旧源码和手工 bundle 的相同代码不能算独立证据。

## 旧写出布局（待外部核验）

以下偏移均为十进制、从文件起始处计，字节序按旧代码的显式 big-endian 写出；它们描述现有代码，不构成 NCP 规范。

| 偏移 | 长度 | 旧代码写入内容 |
| --- | ---: | --- |
| 0–3 | 4 | `NCP\0` 签名 |
| 4–11 | 8 | 块号 1、块长度 36，均为 big-endian UInt32 |
| 12–35 | 24 | ASCII `0100` 版本及最多 20 字符标题；旧 JS 将每个 UTF-16 码元截成低 8 位，非 ASCII 标题的设备解释未验证 |
| 36–39 | 4 | big-endian UInt16 风格代码及固定 `0x02FF` 修改标志 |
| 40–47 | 8 | 锐度、固定对比度/亮度表启用标志、饱和度、色相、三个 `0xFF` 单色占位字节 |
| 48–55 | 8 | 块号 2、块长度 578，均为 big-endian UInt32 |
| 56–63 | 8 | 固定 `0x49 0x30`、输入黑白 0/255、输出黑白、gamma 整数/小数 1/0 |
| 64–121 | 58 | 首字节 18，后续 18 对索引/8-bit 值；索引为 0、15、…、255，余下 21 字节为零 |
| 122–633 | 512 | 256 个 big-endian UInt16 值，名义范围 0…32767 |
| 634–637 | 4 | 末尾零字节 |

旧代码对每个 RGB 节点以 `0.2126R + 0.7152G + 0.0722B` 折成单通道。256 个完整值以 `Math.round(y × 32767)` 后裁剪到 0…32767；18 个压缩值用全表亮度最小/最大值归一化到 0…255，再以 `Math.round` 取整及裁剪。黑白端点按 `Math.round(yMin × 255)` / `Math.round(yMax × 255)` 写成单字节。这里的亮度系数、两种量化、端点计算和 18 对压缩表的相互关系均只由旧代码支持，尚无独立参照。常值表令 `yMax - yMin = 0`，旧代码没有显式错误处理；负值、超白、NaN 和无效 RGB 长度也没有完整输入校验。

风格代码数组覆盖 Vivid `0x00C3`、Standard `0x0001`、Neutral `0x03C2`、D2X Mode 1/2/3 `0x0014`/`0x03D5`/`0x00D6`、Portrait `0x0486`、Landscape `0x04C7`、Monochrome `0x064D`。输入风格名不匹配时旧代码静默选 Neutral。旧 UI 的存储槽为 1…99，锐度 0…9，饱和度和色相各为 -3…3；输出名为 `PICCON01.NCP` 至 `PICCON99.NCP`。这些只是旧版 UI/编码行为，不能直接等同于相机可接受范围。

## 阻塞与解锁条件

`js/lut-ncp.js` 自己注明偏移 56–57 的 `0x49 0x30` 意义未知。块长度、版本、风格代码、`0x02FF`、末尾四字节与 18 对压缩表也缺少可追溯的格式说明；尤其无法证明任意旧输出能被目标 Nikon 相机接受。现有证据不足以确定读写方向以外的设备约束、范围、溢出和舍入契约，因此暂不写 Swift 编码器或将 FULL-06 标记完成。

下一步需取得有型号、固件、基础风格和生成工具版本记录的 Nikon 官方/相机导出 `.ncp` 实样，保存来源 URL 或采集记录及 SHA-256；逐偏移比较多个受控设置的样本，核实未知字段、压缩表、端序、边界和标题编码。随后冻结可支持机型及参数域，以独立工具或 Picture Control Utility 2 读回，并在相应相机上实际导入验证；先写拒绝无损不可表示输入的契约测试，再实现纯 Swift 写出。样本或设备缺席时只能保留研究阻塞，不能以旧 JS 自回归代替外部验证。
