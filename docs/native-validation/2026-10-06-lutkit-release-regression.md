# LUTKit Release 全量回归

## 命令与工具链

在 `/Users/lingru/claude/LUTCalc` 执行：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

工具链为当前工作区的 Swift/XCTest Release 配置，未使用模拟器、WebView、JavaScriptCore 或外部计算内核。

## 结果

命令退出码为 `0`。所有测试套件通过；LUTAnalysis 测试包执行 `93/93`，失败 `0`。回归输出还覆盖项目存储、导出格式、任务 checkpoint、资源恢复、ICC 边界、传递函数和 LUTAnalyst 现有契约。

## 覆盖边界

本次回归证明最近并行改动没有破坏已有 Swift `Double` 数值路径、资源拒绝边界和本地恢复契约。它不提供真实 File Provider/iCloud、iPhone 11 后台恢复、目标调色软件往返或发布公证证据，也不关闭 `.labin` `0/9`、直接查表 `0/45`、任意 3D 全局反求、完整 ICC/HDR/OOTF。Goal 保持 `active`。
