# Canon WideDR 与 Normal/EOS 查表缺口审计

## 范围与源码证据

本轮只审计以下七个旧注册：`EOS Standard`、`EOS Standard (Legal)`、
`Canon Normal 1` 至 `Canon Normal 4`、`Canon WideDR`。`js/gamma.js` 中前六项
均通过 `LUTGammaLUTSimple` 保存 17 个节点；`Canon WideDR` 的启用实现同样是
17 节点 `LUTGammaLUTSimple`。WideDR 另有一段被注释的 `LUTGammaGen` 参数，
但没有公开来源、版本、适用范围或独立非灰轴参照，不能把它当作连续定义。

## 契约先行

新增 `CanonLookupGapContractsTests`：

- 七个名称必须出现在 `blockedLookupRegistrationNames`；
- 原生目录不得为其创建 transfer、色域或预设身份；
- 不能别名为 Rec.709 legacy、BT.1886、Canon C-Log、C-Log2 或 C-Log3。

## 实际验证

```text
swift test --package-path Native/Packages/LUTKit -c release \
  --filter CanonLookupGapContractsTests
```

结果：LUTCatalog `2/2`，失败 `0`，退出码 `0`；日志 SHA-256：
`9f2352b7f980b600be17edd0470c9ee557e3dfc0bbac3ac3589dc980927784b2`。

## 结论

当前只找到旧样条节点和未发布的注释参数，未找到 Canon 可追溯的连续函数、
完整范围/Legal 语义及独立参照。Canon C-Log/C-Log2 是不同的记录 transfer，
Rec.709/BT.1886 也不能解释这些 look 曲线。将 17 点节点拟合为多项式、把
WideDR 的注释参数当规范，或复用相近 Canon transfer 都会改变算法身份。

因此本轮不实现 Swift 公式、不新增目录身份、不搬运或压缩 LUT；七项继续研究
阻塞。此记录不关闭直接查表组（当前 `0/45`），Goal 保持 `active`。
