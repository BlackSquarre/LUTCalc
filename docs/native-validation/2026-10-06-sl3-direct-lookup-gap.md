# S-Log3 后查表组算法缺口审计

## 范围

审计 `LUTGammaLUTSL3` 这组旧 look 注册：ARRI `Amira709`、`Alexa-X-2`；Sony
`LC709A`、`LC709`、`Sony Cine+709`；Panasonic `Varicam V709`；RED
`REDGamma`、`REDGamma2`、`REDGamma3`、`REDGamma4`。共 10 个注册身份，涉及四个
厂商系列。Sony STD 和 Canon 查表项另有审计记录，不在此重复。

## 旧实现与可用证据

`js/gamma.js` 对六个 ARRI/Sony/Panasonic look 和四个 REDGamma 版本保存 64/65
个输出节点，并由 `LUTGammaLUTSL3` 将其与输入 S-Log3 域连接。节点是旧结果数据，
不说明 look 的连续 RGB 映射、输入 LogC/S-Log 版本、矩阵、机型/固件范围或越界
行为。

其中 `Amira709`、`AlexaX2`、`LC709`、`LC709A`、`Cine709`、`V709` 还有历史
`.labin` 夹具。已通过的 `.labin` 解析契约只证明旧格式可读；夹具不可随 App 打包，
也不能作为由公开公式计算的独立参照。仓库的查表盘点要求 ARRI、Sony、Panasonic
官方连续显示变换和非灰轴参照，以及 REDGamma 明确版本的官方定义和独立参照。

## 契约与验证

新增 `SL3LookupGapContractsTests`，要求上述 10 个身份都留在
`blockedLookupRegistrationNames`，并且原生目录不解析为 transfer、色域或预设。

```text
swift test --package-path Native/Packages/LUTKit -c release \
  --filter SL3LookupGapContractsTests
```

结果：LUTCatalog `1/1`，失败 `0`，退出码 `0`。日志 SHA-256：
`bedee9ef7465d195830561d820d6811a58678d7e35b52b083079082174c3dd84`。

## 结论

当前工作区没有这些 look 的官方连续 RGB 函数、完整设备/版本范围和独立非灰轴网格
参照。标准 Rec.709 OETF/BT.1886 EOTF 或原生 S-Log3 transfer 只能覆盖标量传递
函数，不能重建 look 曲线与色彩变换。由节点做样条拟合、拟合多项式，或把 `.labin`
夹具改写成 Swift 数组/权重，均等价于复制旧采样结果。

因此本轮不新增公式或 Swift 算法，不改生产代码，不搬运夹具；该 10 项保持阻塞，
直接查表注册仍为 `0/45`。需要后续获得厂商公开连续定义、版本化适用范围及独立
非灰轴参照后再先写数值契约。Goal 继续 `active`。
