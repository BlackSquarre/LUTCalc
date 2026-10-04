# 2026-10-03 旧 1D cubic 反求非 UI 验收

## 范围

本阶段补齐 FULL-05 的一维旧 `LUTSpline` cubic 反求子集。前向实现仍由 `LegacyCubicCurve1D` 保留；新增分析层按每段 cubic 导数的临界点拆分区间，只对全域严格单值的曲线使用 Brent 反求。常值段、导数换向、多个根和任意三维 LUT 仍明确拒绝。没有修改 UI 视觉、项目生成计划或任意 3D 逆。

## 契约先行与实现

- 先增加契约：单调 cubic 用独立 Hermite 目标值恢复输入；hump 和常值段返回 `nonUnique`；非有限目标返回 `nonFinite`。
- 初次执行暴露测试文件错误地放在 `LUTCoreTests` 并反向链接 `LUTAnalysis`；保留该链接失败输出后，将契约移到已有 `LUTAnalysisTests` 依赖边界，再继续实现。没有把错误 target 的链接失败当作生产失败。
- `LegacyCubicCurve1D` 现在公开只读 `LegacyCubicSegment` 系数；`LUTAnalysis` 新增 `LegacyCubicCurve1D.inverse`。`ImportedLUTAnalyzer.inverseTransfer` 增加显式 `interpolation` 参数，`.tricubicLegacyV1` 才使用 cubic 反求，默认线性路径保持原语义。
- 全局单值检查同时核对每个 segment 的导数端点与顶点；不通过时直接返回 `nonUnique`，不靠加密采样推断可逆性。

## 实际命令与结果

工具链：Xcode 27.0、Swift 6 语言模式、macOS arm64。

Debug 定向：

```sh
swift test --package-path Native/Packages/LUTKit --filter 'RootContractsTests|ImportedLUTAnalysisContractsTests|LegacyCubicCurveContractsTests'
```

结果：`LegacyCubicCurveContractsTests` 3 项、`ImportedLUTAnalysisContractsTests` 5 项、`RootContractsTests` 6 项，均为 0 失败。

Release 定向：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter 'RootContractsTests|ImportedLUTAnalysisContractsTests|LegacyCubicCurveContractsTests'
```

结果：上述 20 项均为 0 失败。已有编译警告为无关测试文件中的 `try` 标记，不影响本包。

完整回归：

```sh
swift test --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包共执行 549 项、0 失败；LUTFormats 的既有 `.labin` 与 NCP 外部夹具各 1 项跳过，命令退出码 0。日志：`/tmp/lutcalc-cubic-inverse-full-20261003.log`。

当前工作区完整 Release 回归执行 549 项、0 失败，2 项既有外部夹具跳过，退出码 0。日志：`/tmp/lutcalc-cubic-inverse-release-full-20261003-r2.log`。

## 独立数值参照

契约曲线样本 `[0, 0.25, 0.75, 1]`、域 `[-1, 2]`，segment 1 的 `t=0.37` 对应输入 `1.37/3`。使用 80 位 Decimal Hermite 系数 `a=-0.25, b=0.375, c=0.375, d=0.25` 独立计算目标值 `0.427424250`；Swift cubic 反求恢复 `1.37/3`，误差不超过 `2e-12`。旧 1D cubic 220 点冻结参照仍为最大尺度化误差 `0`。

## 未完成范围

这只完成严格单值 1D cubic 分析和反求入口。cubic 反求尚未进入生成计划、项目持久化或所有导出服务；组合 shaper 的 cubic 反求、旧 3D 域外 `legacyExtensionV1` 冲突、任意 3D 逆、完整 TF/颜色分离、目标软件往返、性能和发布仍未完成。FULL-05、H07/H10/H14 和 Goal 继续保持 active。
