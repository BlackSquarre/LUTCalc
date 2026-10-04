# H08 强制乱序完成与顺序写出

日期：2026-09-23。接续[提交边界记录](2026-09-23-h08-commit-boundary.md)。本步强制计算块按 `3,2,1,0,7,6,5,4,8` 的顺序返回，验证协调器仍按 R 最快网格顺序写出全部 Double 样本，并维持有界待写缓存。UI 未修改。

## 契约与修改

先在 `LUTJobChecks` 写入 3³ 网格、每块 3 节点、4 个 worker 的确定性门控测试。测试先要求各块到达完成边界，再依次放行指定块，并在协调器确认收到该块后放行下一块。首次 Debug 构建退出码 1，报缺 `GenerationTestHooks` 和可注入的 coordinator 初始化器，确认原实现没有可确定性控制完成顺序的测试接口。

随后在 `LUTJobs/Generation.swift` 增加仅同一 Swift Package 可见的测试钩子，在块计算结束、返回 `TaskGroup` 前挂起，以及在协调器收到结果时回报索引。正式 `public init()` 不注入钩子，原有计算、写入、取消与提交路径保持原语义。门控测试验证接收顺序精确等于 `3,2,1,0,7,6,5,4,8`、写入样本与串行 `CubeGenerator` 的 27 个 RGB64 节点完全相同、待写块峰值恰为 4，任务最终 `completed`。这个接口只用于研发验证，没有在 App 中保存测试样本或旧 LUT。

## 实际命令与结果

```text
swift run --package-path Native/Packages/LUTKit LUTJobChecks
swift run -c release --package-path Native/Packages/LUTKit LUTJobChecks
tools/native-validation/verify-native-subset.sh
```

三条命令实际运行，退出码均为 0；子集入口包含 Swift Release 构建、旧 JS 测试 9/9、静态扫描 35 个 Swift 源文件及此前 H08 取消、文件读回契约。强制乱序检查没有改变网格大小来掩盖误差：它是在明确的 3³ 调度夹具上证明顺序与缓存性质，既有 17³ 数值确定性和 17³ CUBE 读回仍继续通过。H06 的 17³/33³/65³ 数值门槛与夹具保持不变。

修改文件及 SHA-256：`Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift` `1c8fd286deedd07edad3c1052ad7220248daa8dd3825fb671e2b354c186b87a9`；`Native/Packages/LUTKit/Sources/LUTJobChecks/main.swift` `d54762aa5b333b4d79bc5dd9a0e84c1f989dd7ae77a060d12a52c22043bf82ad`。子集脚本与旧数值夹具本步未改；实际工具链仍为本机 Apple Silicon Command Line Tools Swift 6.2.1。

## 未覆盖

本步覆盖一个强制逆序调度和已有 worker/块尺寸组合，尚未做设备峰值内存与时延预算、覆盖授权事务、File Provider/iCloud、iOS 后台终止或真实 App 文件授权。只有 Command Line Tools，XCTest、macOS/iOS/iPadOS `.app`、模拟器、真机与发布门槛未因此通过。H08/FLOW-02/QA-02 仍是部分完成。
