# Tricubic 三维反求取消语义验收

## 范围

本项只验证 `Tricubic3DInverse.analyze` 在 Swift 并发任务被取消时及时传播标准 `CancellationError`。它不改变 Newton 根判定、候选去重、排序或局部 `unresolved` 语义，也不代表任意三维 LUT 全局反求已经完备。

## 先失败契约

新增 `TricubicInverseContractsTests.testCancellationIsPropagatedBeforeScanningCells` 后，未修改实现的 Debug 定向命令为：

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter TricubicInverseContractsTests/testCancellationIsPropagatedBeforeScanningCells
```

结果：失败。已取消的任务仍返回报告，测试报错“cancelled tricubic inverse must not report a result”。该失败证明扫描入口缺少取消检查。

## 实现与验证

在 `Tricubic3DInverse.analyze` 入口、cell 扫描循环、seed 循环和 Newton 迭代循环加入 `try Task.checkCancellation()`；`solveCell` 改为抛出并向上传播取消错误。未修改数值阈值、网格、插值规则、根去重和排序。

工具链：SwiftPM、当前 macOS 主机、Swift Debug 构建。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --skip-build --filter TricubicInverseContractsTests/testCancellationIsPropagatedBeforeScanningCells
```

结果：通过，1 项、0 失败；`git diff --check` 通过。

Release 复验尚未取得，需主代理在无其他 SwiftPM 进程并发时运行相同 `-c release` 命令并保存日志及 SHA。未取得 Release 证据前，本项不得宣称双配置闭合。

## 未覆盖范围

本项未证明任意三维 LUT 全局反求、全根完备性、多解证明、域外行为、`.labin` 或直接查表替代。相关范围继续保持未完成，Goal 继续 `active`。
