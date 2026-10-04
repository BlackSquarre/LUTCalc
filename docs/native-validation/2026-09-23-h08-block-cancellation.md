# H08 每个写块边界的真实取消

日期：2026-09-23。接续[H08 任务与文件阶段记录](2026-09-23-h08.md)。本步在 3³、每块 3 节点的 9 个写块边界逐一确定性挂起，真实调用 `Task.cancel()`，再放行写入；每次均须取消任务、调用输出端 `abort`，且没有提交。UI 没有修改。

先把异步挂起的 `BlockGateSink` 契约写入 `LUTJobChecks`；首次 `swift build --package-path Native/Packages/LUTKit --product LUTJobChecks` 退出码 1，明确报 `append` 的异步方法不符合当时同步 `CubeBlockSink.append` 要求。之后将协议的 `append` 要求改为 `async throws`；`GenerationCoordinator` 原本就以 `try await sink.append` 调用，既有同步 actor sink 仍能符合协议。数值计算与写出顺序没有改变。

## 实际运行

```text
swift run --package-path Native/Packages/LUTKit LUTJobChecks
swift run -c release --package-path Native/Packages/LUTKit LUTJobChecks
tools/native-validation/verify-native-subset.sh
```

三条命令最终退出码均为 0。Debug/Release 的 9 个边界全部得到 `CancellationError`、coordinator 终态 `cancelled`、sink 终态 `aborted`、提交次数 0。既有 17³ 九种 worker/块尺寸确定性、写失败/取消注入、验证/提交边界真实取消和 CUBE 文件读回测试保持通过；子集入口旧 JS 测试 9/9、静态扫描 35 个 Swift 源文件。

修改源码 SHA-256：`Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift` `34b96223d1d38e1ec52d63a10e52734a092a9bcb5155c9ad5608d7a0e74c25f6`；`Native/Packages/LUTKit/Sources/LUTJobChecks/main.swift` `90281883e868757c2a078cbb491ab9adf7e71ee877b27a88e586e4ef7eea6064`；子集入口未因本步改变，哈希 `77fae8e4901bcacafa92d1593f1f4ebbc2fae51735d1e45f2887e039589e12fd`。仍使用 H06–H07 的数值夹具与 3³/17³ 网格，没有放宽误差门槛。

## 限制

本步的边界 sink 在内存中，不证明真实文件临时数据清理、覆盖授权后的旧目标保护、强制乱序完成、峰值内存、File Provider/iCloud 或 iOS 后台行为。当前机器无完整 Xcode/iOS SDK，XCTest、两端 `.app`、模拟器和真机仍未执行。H08/FLOW-02/QA-02 保持部分完成。
