# H08 提交阶段的取消状态契约

日期：2026-09-23。接续[真实 CUBE 文件写块取消记录](2026-09-23-h08-file-cancellation.md)。运行时契约规定：进入 `committing` 后，提交操作按成功或失败结束，不能在可能已执行文件操作后返回“已取消”。本步为这一区分新增确定性测试并修正协调器状态。UI 未改动。

先在 `LUTJobChecks` 加入两个异步提交门控场景：任务进入 `committing` 后真实调用 `Task.cancel()`；一例放行并成功提交，应报告 `completed`；另一例由提交方抛出 `CancellationError`，应报告 `failed` 并调用 `abort`。首次 `swift run --package-path Native/Packages/LUTKit LUTJobChecks` 构建成功但测试退出码 1，暴露原逻辑把提交阶段的该错误标为 `cancelled`。修改 `GenerationCoordinator`，在异常处理前保存是否已进入 `committing`，仅在提交前把 `CancellationError` 分类为 `cancelled`；提交开始后的异常分类为 `failed`。提交成功仍标为 `completed`。

最终实际运行 `swift run --package-path Native/Packages/LUTKit LUTJobChecks` 与 `tools/native-validation/verify-native-subset.sh`，退出码均为 0；后者包含 Release 构建与 Release `LUTJobChecks`，旧 JS 测试 9/9，静态扫描 35 个 Swift 文件。此前 H08 的确定性、取消、文件读回契约均继续通过。没有更改数值计算、网格、位宽、插值或阈值。

修改源码 SHA-256：`Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift` `13d74de0c93fe88a84a32f9fdcd01b94856dc59beb034755175e5d714b0e2d03`；`Native/Packages/LUTKit/Sources/LUTJobChecks/main.swift` `2a9e2dedf9881e7ab6aa80795b60720af75171ae80e3f5e8652d7cef455172ce`。阶段数值夹具沿用 H06–H07，研发脚本和 Native App 资源未改。

此测试使用门控 sink，证明 coordinator 的状态语义；它不证明真实 File Provider 提交一半时能回滚，也不处理提交方在实际完成后抛错误的不可判定情况。覆盖授权替换、平台文件协调、真机和性能预算仍待验证。本机仅有 Command Line Tools，XCTest、两端 `.app`、模拟器与真机未执行；H08/FLOW-02/QA-02 仍不勾选。
