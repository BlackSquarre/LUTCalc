# LUTAnalyst 全局逆缺口复验

## 范围

本轮只复核现有三线性、legacy tricubic 和组合 shaper/colour 反求契约，继续
处理算法缺口，不扩展 UI、任务调度或发布范围。目标是确认当前严格可证明子集
没有回归，并重新记录 tricubic 全局根证明的前置条件。

## 已确认的严格子集

- 三线性严格仿射单元可用矩阵反解证明单元内唯一解或无解；奇异单元保持
  `unresolved`。含混合项单元即使有限 Newton 找到根，也不提升为全局结论。
- 三线性网格单元完整枚举，目标不在任何输出包围盒时可证明无解；共享面根按
  输入坐标去重。
- tricubic 完整枚举 `(size - 1)^3` 单元，Bernstein 输出包围盒不命中目标时可
  证明该单元无根；候选单元只保留生产采样器回放通过的 Newton 根，并继续标记
  `unresolved`。
- 组合 shaper/colour 只有下层颜色逆与各 shaper 通道都无未决状态时才可报告
  全局完备；折叠 shaper、奇异颜色单元和 tricubic 候选继续传播 `unresolved`。

## 实际复验

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'TricubicInverseContractsTests|TrilinearInverseContractsTests|CombinedShaperColourInverseContractsTests|ImportedLUTAnalysisContractsTests'
```

工具链为当前 Apple SwiftPM Release。第一次运行因取消测试任务在 `cancel()` 前
完成而出现 1 项调度竞态红测；没有算法断言失败。等待后按同一命令独立重跑，
`LUTAnalysisTests` 共 52 项、0 失败、退出码 `0`。重跑日志：
`/tmp/lutanalyst-gap-recheck-20261006-rerun.log`，SHA-256：
`336e00f2765790df15b05834b68451a626ab601ea1af2dbc4c8c44d030f6d38b`。

## 仍未闭合

tricubic 候选单元仍缺可复核的导数区间包络、Bernstein 细分根隔离、奇异集合处置
以及共享面闭边界去重证书。有限 Newton 种子与单点 Jacobian 不能证明全根、无根
或多解完备性；当前不实现猜测性区间算法，也不扩大 `isGloballyComplete` 的含义。
任意 3D LUT 全局逆、自动 transfer/colour 分离和完整重建继续未完成，Goal 保持
`active`。
