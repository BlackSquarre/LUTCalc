# H10 严格单调 1D 分析阶段验收

日期：2026-09-26。

## 范围

本阶段在既有 `RootSolver` 和 `MonotonicCurve1D` 之上增加纯 Swift 的结构分析报告。报告只读取用户提供的 `Double` 样本，不修改端点、不插值修补，也不把旧网页实现中的首尾斜率调整当作原始数据。它明确记录递增、递减、常量或反单调方向、严格性、平段索引、反转索引和相邻步长范围。严格单调曲线才标记为可用单值反求；平段仍由既有 `nonUnique` 结果处理，反单调输入仍拒绝构造反求对象。

## 修改

- `Native/Packages/LUTKit/Sources/LUTAnalysis/MonotonicCurve1D.swift`
  - 新增 `CurveMonotonicDirection`、`MonotonicCurve1DAnalysis` 和 `MonotonicCurve1DAnalyzer`。
  - `MonotonicCurve1D` 保存分析报告，并复用同一结构判定反单调输入。
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/MonotonicAnalysisContractsTests.swift`
  - 覆盖严格递增、递减含平段、反转输入和常量输入。

源码 SHA-256：

- `MonotonicCurve1D.swift`：`3b9adfee94b70823c77079e14a9f7738287ff29850e829ab991e24fc4c44fc45`
- `MonotonicAnalysisContractsTests.swift`：`b3d6c2a32f66b13616e2bb59ec8f56591381a2950261886cf3372d20db967e22`

## 实际验证

1. `swift test --package-path Native/Packages/LUTKit -c release --filter MonotonicAnalysisContractsTests`
   - 退出码 `0`。
   - `MonotonicAnalysisContractsTests`：4/4 通过。
2. `swift test --package-path Native/Packages/LUTKit -c release`
   - 退出码 `0`。
   - 当前 Swift 测试清单：256 项；本次完整包测试通过。
3. `git diff --check`
   - 退出码 `0`。
4. `bash tools/native-validation/verify-native-release.sh > /tmp/lutcalc-h10-strict-monotonic-release-20260926.log 2>&1`
   - 原生验证与三平台 Release 构建完成；三个 App 包资源审计通过。
   - 入口最终退出码为 `2`，唯一失败项是缺少真实 `docs/native-validation/full-scope-acceptance.json`；这不是代码、测试或构建失败。
   - 日志 SHA-256：`2d94d758dfa06250452a64b5241fa5efdcbd476c76732d09a493cb1141ff94ff`。

## 结论与边界

本阶段证明了严格单调 1D 的结构诊断、平段多解和反单调拒绝路径；它没有实现旧 cubic/tricubic、完整 TF/颜色分离、任意 3D 反求或 LUTAnalyst 的完整分析工作流。任意 3D 反求仍是研究阻塞，不能由本报告推断全局可逆性。双端 App、真机 Files/File Provider 和全量发布清单仍未验收。
