# LUTAnalyst tricubic 严格仿射子集边界

## 复核目的

本轮尝试确认旧 `LegacyTricubicVolume3D` 是否可以像三线性分区一样，针对单个 cell 认证严格仿射映射，并在该子集内使用三元矩阵反解。认证必须保持 `Double`、现有 ghost-node 规则、既有 tricubic 插值权重和 `2e-12` 残差门禁；不能用容差把非零高阶项当作零。

## 当前结论

没有新增生产仿射认证。原因是现有 `LegacyTricubicVolume3D` 对外只提供生产取样、解析 Jacobian 和 Bernstein 输出包围盒；它没有暴露 cell 的完整多项式系数或高阶项证书。仅凭有限采样点、Newton 根、Jacobian 在某一点为常数，不能证明 cell 内所有二次、三次和混合项都严格为零。

旧 sampler 的 ghost-node 值还依赖 `ghost(far:third:second:near:)` 的分段单调性规则。即使原始网格来自数学上的仿射模型，认证也必须对生成后的 64 个 stencil 值逐项构造张量积多项式，并证明所有总次数大于一的系数为精确零。使用 `abs(coefficient) <= tolerance` 会把边界根和高条件数映射误分类，因此不符合数值契约。

## 已执行验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter TricubicInverseContractsTests
```

工具链：Apple SwiftPM Release，2026-10-06。

结果：`TricubicInverseContractsTests` 执行 12 项，失败 0，退出码 0。现有契约覆盖生产回放、解析 Jacobian 独立有限差分、Bernstein overshoot 包围盒、恒等网格、折叠双根、共享 cell 边界去重、域最大值、域外无候选、奇异映射、迭代耗尽、非单位域和非法参数。

这些测试证明当前局部诊断与保守 `unresolved` 语义，不证明任意 tricubic cell 的全根完备性，也不证明仿射子集可自动从 LUT 样本推断。

## 后续关闭条件

要重新打开生产实现，必须先补充独立的 cell 多项式系数提取契约：覆盖内部 cell、边界 cell、ghost-node 分支和非单位域；对每个输出通道逐项证明高阶系数精确为零，再用独立矩阵反解和生产 sampler 回放验证。任何系数非零、非有限、奇异或无法证明的 cell 都必须保持 `unresolved`。在该证据出现前，继续沿用现有全局 tricubic 阻塞记录，不扩大 `isGloballyComplete` 的含义。

本项不改变 `.labin`、直接查表、完整 ICC、HDR/EDR/OOTF 或 Goal 状态；Goal 继续保持 `active`。
