# 直接查表与间接资源台账对账

日期：2026-10-06。

## 对账结果

- 旧 JS 注册快照 `research/colour/2026-09-23/current-inventory.json` 标记的 `sampleTableBased` 项共 `45` 个，分类为 `LUTGammaDLog=1`、`LUTGammaIOLUT=9`、`LUTGammaLUTSL3=10`、`LUTGammaLUTSimple=25`。
- Swift `AlgorithmCatalog.blockedLookupRegistrationNames` 共 `45` 个；集合与快照名称逐项完全相等，没有遗漏、重名或额外别名。
- 根目录实际 `.labin` 文件共 `9` 个，文件名集合与快照 `assets` 集合完全相等：`LC709.labin`、`LC709A.labin`、`s709.labin`、`Cine709.labin`、`Amira709.labin`、`AlexaX2.labin`、`V709.labin`、`cpoutdaylight.labin`、`cpouttungsten.labin`。
- 研究目录中的 `.cube`、`.ctl`、`.dctl` 和验收 artifacts 是研究/用户导入或结果资产，不属于 App 内置资源；本轮不将其误算为内置算法。

## 自动契约

新增 `LookupResourceInventoryContractsTests`：读取已冻结研究快照，对比直接查表名称和四类数量，并对根目录 `.labin` 文件集合做实际文件系统对账。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LookupResourceInventoryContractsTests
```

结果：Release 定向 `2/2` 通过，失败 `0`，退出码 `0`。首次运行仅修正了测试从 `#filePath` 计算仓库根目录时少退一层的路径错误，最终结果无台账差异。

## 范围结论

本轮没有可安全关闭的直接查表或间接 `.labin` 子集。45 项直接查表替代仍为 `0/45`，9 个 `.labin` 算法替代仍为 `0/9`。没有搬运样条、压缩数组或旧资源，也没有修改生产算法；后续关闭条件仍是公开连续定义、适用范围、非灰轴语义和独立参照。
