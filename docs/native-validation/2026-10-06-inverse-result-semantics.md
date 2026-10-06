# LUTAnalyst 反求结果语义验收

## 范围

本项只审计三线性与旧三次反求的重复根结果稳定性。相同输入在相邻 cell、seed 或边界路径中可能被多次发现；保留候选时应选择生产采样器重放残差较小者，然后按输入 `r/g/b` 排序。该规则不声称完成任意三维 LUT 的全局反求或全根完备性。

## 实现

`Trilinear3DInverse` 与 `Tricubic3DInverse` 增加按 `sameInput` 聚合的 `upsert` 路径。重复输入不再无条件保留首个候选；当新候选的有限重放残差更小时替换旧候选。最终报告仍按输入坐标升序排列，状态分类仍以 unresolved 数量和去重后根数为准。目标 `RGB64` 的非有限值仍在公共入口返回 `.nonFinite`；`RGB64` 本身拒绝非有限样本，避免非有限根进入报告。

## 验证命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter 'TrilinearInverseContractsTests|TricubicInverseContractsTests'
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'TrilinearInverseContractsTests|TricubicInverseContractsTests'
git diff --check
```

Debug 与 Release 均退出码 0；两个反求测试组共 22 项通过（Release 编译仅有既有无关 warning）。`git diff --check` 通过。

## 未覆盖

没有改变搜索 seed、Newton 预算、cell 认证边界或多解完备性。`.labin`、直接查表、完整 ICC、HDR/EDR/OOTF 和平台发布验收仍未完成。
