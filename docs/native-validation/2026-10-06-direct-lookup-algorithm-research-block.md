# 直接查表算法替代研究阻塞复核

## 范围

本轮只复核旧注册表中 45 个直接查表名称，判断是否有公开连续公式、明确适用范围和独立参照，可以在不携带等价采样表的前提下实现 Swift `Double` 路径。用户主动导入 LUT 的解析和执行路径不在本轮范围内。

## 审计结果

45 个名称仍分为四类旧实现：`LUTGammaDLog` 的 DJI DLog-M、`LUTGammaIOLUT` 的九个输入／输出查表、`LUTGammaLUTSL3` 的十个 S-Log3 后显示查表，以及 `LUTGammaLUTSimple` 的二十五个 SimpleLog 后查表。当前资料只给出旧注册名称和有限采样行为，没有同时提供连续定义、版本化设备范围、非灰轴行为及可独立重建的参照。

不能从通用 S-Log3、SimpleLog 或 SMPTE 240M 公式推出 Sony、ARRI、Canon、RED、Panasonic 显示变换及 Nikon/Canon picture style；DJI DLog-M 也不能由已实现的 DJI D-Log2 推断。把旧数组改写为 Swift 常量、压缩文本、Base64、纹理或拟合多项式仍属于等价内置采样数据，违反迁移约束。

## 现有防误注册证据

`AlgorithmCatalog.blockedLookupRegistrationNames` 冻结全部 45 个名称；目录契约逐项确认 `transfer(named:)`、`colorSpace(named:)` 和 `preset(named:)` 均为空，防止资料不足的查表项被误登记为原生算法。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity
```

结果：Xcode 27 / Swift 6，macOS arm64，执行 1 项、失败 0、退出码 0。

## 结论与后续条件

本轮没有可安全实现的新增算法，不修改生产代码、不增加目录身份，直接查表替代保持 `0/45`。任一项目只有在取得公开连续定义、适用机型／版本、非灰轴语义和独立 17³／33³／65³ 参照后，才可先加失败契约，再实现 `Double` 路径并更新台账。完整 LUTAnalyst、格式往返、平台和发布验收不受本轮影响；Goal 保持 `active`。
