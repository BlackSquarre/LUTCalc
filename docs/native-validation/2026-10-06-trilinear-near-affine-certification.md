# 三线性反求近似仿射认证边界验收

## 范围

本验收覆盖三线性 3D LUT 反求中“近似仿射”单元的无解证明边界。混合项即使小于请求容差，也可能在单元边界产生真实根；因此不能把近似仿射模型用于严格的 `noSolution` 认证。

## 契约与修复

先加入 `testNearAffineMixedTermCannotBeUsedToCertifyNoSolution`：构造混合项为 `1e-13` 的单元，并验证边界根仍被生产三线性采样器回放为唯一根。实现将 `affineCellResult` 的严格仿射判定改为仅接受逐项精确零混合项；其他单元继续走候选求解并在无法证明时报告 `unresolved`。

## 实际验证

工具链：SwiftPM、当前 Xcode Swift 编译器、macOS 主机。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter TrilinearInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter TrilinearInverseContractsTests
git diff --check
```

Debug 与 Release 的 `TrilinearInverseContractsTests` 均执行 13 项、0 失败；`git diff --check` 通过。Release 进程曾与其他 SwiftPM 任务共享构建缓存，最终在等待完成后正常退出并报告 13 项通过。

## 未覆盖

该修复只关闭近似仿射无解误证边界，不证明任意 3D LUT 全局根完备性、跨单元多根完备性或连续域逆。`.labin`、直接查表、完整 ICC/HDR/OOTF 与平台发布验收仍未完成。
