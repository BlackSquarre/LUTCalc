# 2026-10-04 内置查表替代台账

## 目的与边界

本台账只追踪旧 App 中禁止直接搬入原生运行时的查表依赖。它不把旧 `.labin`、JavaScript 数组、样条控制点、压缩数据或拟合模型加入 Swift；用户主动导入的 LUT 仍属于另一条用户数据路径。只有取得公开连续定义、适用范围和独立参照后，项目才可以从“阻塞”转为可实现。

来源盘点命令：

```sh
node tools/research/snapshot-colour-inventory.js
for f in *.labin; do [ -f "$f" ] && shasum -a 256 "$f"; done | sort
```

## 九个 `.labin` 资源

| 文件 | 旧用途 | SHA-256 | 原生状态 | 关闭条件 |
| --- | --- | --- | --- | --- |
| `LC709.labin` | Sony LC709 | `085a80e939a33430cc622cd7847d31bbd05024e173388a768568a96b451a88fb` | 公式缺失，禁止打包 | Sony 官方连续定义、版本和独立非灰轴参照 |
| `LC709A.labin` | Sony LC709A | `2effa330c4df7dda5d13a135f7dc4d7c1930c24a6d9d8f7e999cba187188b76c` | 公式缺失，禁止打包 | Sony 官方连续定义、版本和独立非灰轴参照 |
| `s709.labin` | Sony s709 | `c0d4de697358f9520b7338d4b64b8904878397a20708def4c58eee05e777e8d1` | 公式缺失，禁止打包 | Sony 官方连续定义、适用机型和独立参照 |
| `Cine709.labin` | Sony Cine+709 | `b2c398048bcdea7a7bb06c56f41f122d822cf822fb0342ea1a193ea7c4402093` | 公式缺失，禁止打包 | Sony 官方连续定义、版本和独立参照 |
| `Amira709.labin` | ARRI Amira709 | `218a3b5432b180bb5aafbc614385d34a7a9e1c9480f98a45ffc643965abbb9be` | 公式缺失，禁止打包 | ARRI 官方连续定义、相机代际和独立参照 |
| `AlexaX2.labin` | ARRI Alexa-X-2 | `2d04eb19780ab0a91899ea98c4ce6e1430075d5e67636b2f675b6532d56ebdc7` | 公式缺失，禁止打包 | ARRI 官方连续定义、适用 LogC 版本和独立参照 |
| `V709.labin` | Panasonic Varicam V709 | `f835bcb68766a119f11af2ba74c186088c6541e79db4bfb992abe9439f887c48` | 公式缺失，禁止打包 | Panasonic 官方连续定义、机型／固件范围和独立参照 |
| `cpoutdaylight.labin` | Canon CP IDT Daylight 输出变换 | `551e41b3c03edbd21d09f514865515b932c4bff581b759d313996fade0bd4dcf` | CP IDT 资料阻塞，禁止打包 | Canon 官方版本化矩阵／色调定义和独立参照 |
| `cpouttungsten.labin` | Canon CP IDT Tungsten 输出变换 | `335f68f5650db368b25f2971e5127336a0ff826a488051ee86954efc4b25afb7` | CP IDT 资料阻塞，禁止打包 | Canon 官方版本化矩阵／色调定义和独立参照 |

## 45 个直接查表注册

下表中的“旧来源”是旧注册类；它只用于审计定位，不是原生实现来源。

| 注册项 | 旧来源 | 原生状态 | 关闭条件 |
| --- | --- | --- | --- |
| DJI DLog-M | `LUTGammaDLog` | 采样曲线，公式缺失 | DJI 公开连续定义、设备范围和独立全域参照 |
| DJI Mini 2 | `LUTGammaIOLUT` | 输入／输出查表 | DJI 公开连续定义、Rec.709 语义和独立参照 |
| s709 | `LUTGammaIOLUT` | 输入／输出查表 | Sony 公开连续定义和独立参照 |
| Rec709 (800%) | `LUTGammaIOLUT` | 输入／输出查表 | 公开连续定义、范围和独立参照 |
| Nikon Standard | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、机型范围和独立参照 |
| Nikon Neutral | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、机型范围和独立参照 |
| Nikon Vivid | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、机型范围和独立参照 |
| Nikon Monochrome | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、通道语义和独立参照 |
| Nikon Portrait | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、机型范围和独立参照 |
| Nikon Landscape | `LUTGammaIOLUT` | 输入／输出查表 | Nikon 公开连续定义、机型范围和独立参照 |
| Amira709 | `LUTGammaLUTSL3` | S-Log3 后查表 | ARRI 官方连续显示变换和独立非灰轴参照 |
| Alexa-X-2 | `LUTGammaLUTSL3` | S-Log3 后查表 | ARRI 官方连续显示变换和独立非灰轴参照 |
| LC709A | `LUTGammaLUTSL3` | S-Log3 后查表 | Sony 官方连续显示变换和独立非灰轴参照 |
| LC709 | `LUTGammaLUTSL3` | S-Log3 后查表 | Sony 官方连续显示变换和独立非灰轴参照 |
| Sony Cine+709 | `LUTGammaLUTSL3` | S-Log3 后查表 | Sony 官方连续显示变换和独立非灰轴参照 |
| Varicam V709 | `LUTGammaLUTSL3` | S-Log3 后查表 | Panasonic 官方连续显示变换和独立非灰轴参照 |
| REDGamma | `LUTGammaLUTSL3` | S-Log3 后查表 | RED 官方版本化显示变换和独立参照 |
| REDGamma2 | `LUTGammaLUTSL3` | S-Log3 后查表 | RED 官方版本化显示变换和独立参照 |
| REDGamma3 | `LUTGammaLUTSL3` | S-Log3 后查表 | RED 官方版本化显示变换和独立参照 |
| REDGamma4 | `LUTGammaLUTSL3` | S-Log3 后查表 | RED 官方版本化显示变换和独立参照 |
| EOS Standard | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义、范围和独立参照 |
| EOS Standard (Legal) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义、Legal 语义和独立参照 |
| Canon Normal 1 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义和独立参照 |
| Canon Normal 2 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义和独立参照 |
| Canon Normal 3 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义和独立参照 |
| Canon Normal 4 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义和独立参照 |
| HG3250G36 (HG1) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG4600G30 (HG2) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG3259G40 (HG3) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG4609G33 (HG4) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG8000G36 (HG5) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG8000G30 (HG6) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG8009G40 (HG7) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| HG8009G33 (HG8) | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Cinegamma1 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Cinegamma2 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Cinegamma3 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Cinegamma4 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD1 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD2 - x4.5 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD3 - x3.5 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD4 - SMPTE240M | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD5 - Rec709 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Sony STD6 - x5 | `LUTGammaLUTSimple` | SimpleLog 后查表 | Sony 官方连续定义和独立参照 |
| Canon WideDR | `LUTGammaLUTSimple` | SimpleLog 后查表 | Canon 官方连续定义和独立参照 |

## 本轮结论

台账共覆盖 9 个资源和 45 个直接查表注册。当前没有一项同时满足“公开连续公式、适用范围明确、独立参照可构造、无需携带等价采样表”四个条件，因此本轮不新增 Swift 算法身份、不改变目录计数、不改变默认路由。后续一旦取得某项公开公式，必须先增加失败契约，再实现 `Double` 路径、独立参照和 17³／33³／65³ 验收；其余项目继续标记为研究阻塞。
