# SPI1D 文件事务阶段验收

日期：2026-09-24。范围：FULL-06 的 `.spi1d` 生成路径中，取消和本地文件覆盖的包级契约；不代表 File Provider 或真机文件保存验收。

## 契约与结果

先新增 `SPI1DGenerationContractsTests` 的三项契约。首次编译因测试中将 `await` 放入 XCTest 自动闭包而失败，改为读取 actor 状态后断言；没有修改生产实现。随后用受控写块门确保任务已经进入首个写块，再调用真实 `Task.cancel()`。协调器返回 `CancellationError`、状态为 `cancelled`，底层 `FileSPI1DSink` 为 `aborted`，目标及任务临时文件均不存在。

另两项分别验证：默认拒绝覆盖时既有字节不变且未创建临时文件；明确允许覆盖但提交前目标被外部改写时返回 `targetChanged`，保留外部字节并清理临时文件。三项均通过。它们验证已有实现的边界，没有增加新的生产算法或降低 Double 精度。

实际命令：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter SPI1DGenerationContractsTests
swift test -c release --package-path Native/Packages/LUTKit
```

筛选组 8 项、0 失败。完整 Swift Release XCTest 按 8 个测试 bundle 的 `All tests` 汇总为 61 项、0 失败；日志 `/tmp/lutcalc-spi1d-full-swift-test-20260924.log`。首个契约编译失败日志为 `/tmp/lutcalc-spi1d-contract-red-20260924.log`，受控取消的通过日志为 `/tmp/lutcalc-spi1d-contract-gated-20260924.log`。完整测试在受控写块门加入前执行；最终受影响组已在加入后单独重跑。

## 边界

此处只覆盖本地文件事务。SPI1D 真机生成、Files/File Provider 授权与分享、目标软件导入及完整 FULL-06 仍待实际验证。iPhone Air 实体设备在本轮复核时为 `unavailable`；指定设备构建无法匹配目标，退出码 70。不能把包级事务或模拟器安装称为真机保存证据。
