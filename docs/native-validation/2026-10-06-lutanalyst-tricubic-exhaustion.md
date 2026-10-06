# LUTAnalyst tricubic 迭代耗尽边界验收

## 范围

本轮只修复旧 tricubic 局部反求的保守诊断边界。若目标输出落在某个 cell 的已认证输出包围盒内，而 Newton 候选在有限迭代中未能证明收敛，结果必须保留为 `unresolved`，不能静默变成无解。该项不声称完成任意三维 LUT 全局反求、全根完备性、多解证明或生成接线。

## 实现

`Tricubic3DInverse.solveCell` 对所有未收敛候选统一计入 unresolved。此前只有触发奇异、非有限或步长停滞时才计入；普通迭代预算耗尽会被漏报为无解。生产 sampler 回放和既有 cell 包围盒认证逻辑保持不变，最终路径仍使用 `Double`。

## 契约与结果

- 新增 `testIterationExhaustionInsideCertifiedBoundsIsUnresolved`，覆盖极小容差下目标仍在认证包围盒内但无法在有限精度内完成证明的情况。
- Debug 命令：`swift test --package-path Native/Packages/LUTKit -c debug --filter TricubicInverseContractsTests`，9 项通过。
- Release 命令：`swift test --package-path Native/Packages/LUTKit -c release --filter TricubicInverseContractsTests`，9 项通过。
- 工具链：Apple Swift 6.4，`swift-driver 1.168.6`，arm64 macOS 27。
- 日志：`artifacts/2026-10-06-lutanalyst-tricubic-exhaustion/debug.log`、`release.log`。
- SHA-256：`f132f80f117036a684e763f46070f0e74f5738842c0bdc9f17d48b0b6159529f`（Debug）；`79764782b1c7f8825448d4eed50a664a1e3beb42aca7b83277e1d954742c4c48`（Release）。
- `git diff --check` 通过。

## 未覆盖范围

Newton 种子完备性、所有根的数学证明、奇异 cell 的完整根集、自动 transfer/colour 分离、组合 shaper 的全局完备性、`.labin` 替代、直接查表替代和完整 LUTAnalyst 重建仍未完成。Goal 保持 `active`。
