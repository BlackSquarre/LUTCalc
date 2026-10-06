# tricubic 区间根隔离审计

## 审计范围

本记录只判断 `LegacyTricubicVolume3D` 是否已有足够的公开数据，能够安全加入
tricubic 单元的全局根隔离。它不改变生产采样器、网格、ghost-node 规则、`Double`
精度或反求阈值。

## 当前可证明的部分

- `cellOutputBounds` 将生产 Catmull-Rom 张量积多项式转换为 Bernstein 系数，并用
  系数包围盒排除目标值不可能落入的单元。这可以证明单元无解，但不能证明候选单元
  内没有根。
- 目标值命中包围盒后，有限 Newton 种子加生产 sampler 回放只能证明已找到的根；
  不能证明没有遗漏根、没有切向根或没有共享面上的重复分支。
- 对任意输出通道，单元内仍可能出现三次多项式的三个根，例如
  `F(x,y,z) = (x, y, (z-0.1)(z-0.5)(z-0.9) + c)`。因此不能把单通道括区间的
  经验结果提升为三维全根结论。

## 可行但尚未具备的证书

1. **Bernstein 细分**：需要保存每个输出分量的完整张量积 Bernstein 系数，在每次
   二分后重新计算子盒系数；包围盒不命中时可证明无根，系数符号条件满足时可继续
   做面向目标的隔离。现有 API 只返回极值区间，没有暴露系数或细分预算。
2. **区间 Newton/Krawczyk**：需要对 `F(X)-target` 和 Jacobian `J(X)` 同时建立
   向外舍入的区间包络。当前 `sampleWithJacobian` 只给单点值和 Jacobian，不能把
   单点 Jacobian 当作整个盒子的导数证书；ghost-node 分段和 cell 共享面也必须在
   区间边界中显式处理。
3. **唯一根证书**：需要在同一盒子上满足 Krawczyk 包含条件，或使用可追溯的
   Poincaré–Miranda 面符号条件并处理零面。任一条件失败只能细分或保持
   `unresolved`，不能回退到 Newton 的唯一根判定。
4. **跨单元去重**：隔离盒必须保存闭边界，邻接 cell 的共享面需要确定性规范化；
   根接近 ghost-node 边界时还要同时验证两侧生产 sampler 的值和导数。

## 结论

本轮没有新增生产代码。若在当前数据模型上直接实现区间 Newton，会缺少导数区间
和向外舍入证书，属于猜测性数值算法；若只用有限 Newton 或单点 Jacobian，则不能
关闭任意 3D LUT 的全根完备性。现有 `Tricubic3DInverse` 因此继续保持候选单元
`unresolved`，仅对包围盒外目标返回全局 `noSolution`。

后续实现前置条件是：先为生产 tricubic 多项式提供可复核的 Bernstein 系数/导数
区间接口，再以独立高精度参照和固定资源上限建立契约测试；在此之前不扩大
`isGloballyComplete` 的含义。

