# LUTAnalyst tricubic 全局完备性研究阻塞

## 最小复现模型

旧 `LegacyTricubicVolume3D` 在单元内是三次张量积多项式。即使只观察一个输出通道，也可能出现

```text
F(x,y,z) = (x, y, (z-0.1)(z-0.5)(z-0.9) + c)
```

其中第三通道对同一目标值存在最多三个不同根。有限 Newton 初值集合和迭代上限可以回放确认已找到的根，但不能证明没有遗漏另一个根；Jacobian 奇异或根靠近共享面时也不能由输出包围盒直接分类为无解。

## 当前边界

- 当前实现共享生产 tricubic sampler、解析 Jacobian 和 Bernstein 输出包围盒。
- 包围盒命中但 Newton 未收敛时返回 `unresolved`，不会报告 `noSolution`。
- 已回放的根仍可作为诊断结果返回，但不能据此宣称全局唯一或全根完备。
- 报告新增 `isGloballyComplete`；只要存在输出包围盒候选单元，即使已有回放根也保持 `unresolved`，只有无候选单元才报告全局完备。
- 组合 shaper 复用该状态：已回放的 identity/folded 根继续返回，但上层报告同步为 `unresolved`，不把局部候选当作全局结论。
- 组合报告显式暴露 `isGloballyComplete`；颜色或 shaper 任一侧存在未决项时为 `false`。

## 关闭条件

需要对每个单元使用可证明的区间根隔离／细分方法，处理三次张量积的所有候选根、奇异集合、共享面去重和有限资源上限，并用独立高精度参照核对。当前没有在不改变插值规则或放宽误差阈值的前提下完成该证明，因此不新增生产全局求解器。

该记录不减少 `.labin` `0/9`、直接查表 `0/45`，Goal 继续保持 `active`。
