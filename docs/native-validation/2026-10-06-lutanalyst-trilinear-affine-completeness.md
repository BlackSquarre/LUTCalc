# LUTAnalyst 三线性严格仿射单元完备性验收

## 范围

本包只处理三线性网格中三个混合项和三阶混合项都严格为零的单元。此时单元映射是仿射函数，可以用矩阵反解完整分类为唯一解、单元外无解或奇异未决。含任意混合项的单元继续使用有限 Newton 候选，并在无法证明时返回 `unresolved`。

## 契约与实现

- `Trilinear3DInverseReport` 新增 `enumeratedBoxCount`、`candidateBoxCount` 和 `isGloballyComplete`。
- 所有空间单元都会计入枚举数；输出包围盒命中的单元计入候选数。
- 只有没有未决候选单元时才报告 `isGloballyComplete=true`；非有限输入为 `false`。
- 含混合项的单元即使有限 Newton 种子找到已回放根，也保留 `unresolved`，因为有限种子不能证明没有遗漏根；分段仿射折叠网格仍可报告可证明的 `multiple`。
- 严格仿射身份网格、仿射单元外无解、全局输出范围外无解和奇异折叠映射均有契约覆盖。

## 实际验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisTests.TrilinearInverseContractsTests
```

结果：14 项测试通过，0 失败。先行契约先发现全局无候选时的空间单元计数边界，随后又发现有限 Newton 根不能被误报为全局完备；两处均修正后复验通过。

## 未覆盖范围

该证据不证明含混合项三线性单元的全根完备性，不覆盖 tricubic 全局反求、任意 3D LUT 自动分离或完整重建接线。Goal 继续保持 `active`。
