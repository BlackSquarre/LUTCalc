# H08 CUBE 文件写块取消与临时文件清理

日期：2026-09-23。接续[内存 sink 每块取消记录](2026-09-23-h08-block-cancellation.md)。本步在真正的 `FileCubeSink` 写入每个块后挂起，以 3³、每块 3 节点覆盖 9 个写块边界；调用实际任务的 `Task.cancel()` 后放行，核对目标不存在、任务临时文件不存在、没有提交。UI 未改动。

先将异步转发真实文件 sink 的测试写入 `LUTJobChecks`。首次 Debug 构建退出码 1：`CubeBlockSink` 的 `prepare`、`commit`、`abort` 当时为同步协议要求，异步包装器无法符合。将这三项协议要求改为异步；`GenerationCoordinator` 本来已以 `await` 调用，既有同步 actor sink 继续符合要求。此改动也为未来 File Provider 的异步准备与提交保留接口，但**没有证明** File Provider 行为。

## 实际验证

```text
swift run --package-path Native/Packages/LUTKit LUTJobChecks
tools/native-validation/verify-native-subset.sh
```

两条命令最终退出码 0；子集入口包含 Release 构建及 Release `LUTJobChecks`。9 个边界均得到 `CancellationError`、coordinator `cancelled`、真实文件 sink `aborted`、包装器提交次数 0。每次取消后读取本次自有测试目录，目录为空，说明既无目标 CUBE，也无 `.lutcalc-*.tmp` 任务临时文件；随后原有 17³ 正常导出读回和既有目标拒绝覆盖契约仍通过。旧 JS 测试 9/9，静态扫描 35 个 Swift 源文件。

修改文件及 SHA-256：`Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift` `3649132b1007ffd215baf5eafa1bce3434c6db48f14e6f9cb856a45d5e58cb40`；`Native/Packages/LUTKit/Sources/LUTJobChecks/main.swift` `31182a689c313fdd3741afcc4e99a278df869b5ea34fd46536fdb84176240033`；子集入口未改，仍为 `77fae8e4901bcacafa92d1593f1f4ebbc2fae51735d1e45f2887e039589e12fd`。数值夹具沿用此前阶段，不涉及阈值、位宽或采样网格变更。

## 未覆盖

这证明本地文件系统、已有实现和这 9 个确定性写块边界；强制逆序块完成、覆盖授权后的旧目标保护、磁盘故障各点、iCloud/File Provider、设备峰值内存与后台终止仍待验收。当前机器无完整 Xcode/iOS SDK，XCTest、两端 `.app`、模拟器和真机均未执行。H08/FLOW-02/QA-02 仍保持部分完成。
