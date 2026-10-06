# Canon C-Log legacy 计划色域身份验收

## 范围

本次只补充 Canon C-Log legacy 计划的输入/输出方向和两端色域身份。legacy 分段公式、范围、Double 路径和目录元数据未修改。

## 契约与实现

新增方向、输入色域和输出色域变化契约；实现将 `analytic-canon-clog-legacy-v1` 改为 `directionalAndSpaces`。既有实际冻结 JavaScript 参照继续作为公式契约。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter CanonCLogContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 退出码 `0`，`CanonCLogContractsTests` 4/4 通过，实际冻结 JavaScript 参照继续通过。整包 Release 日志 `/tmp/lutkit-full-20261006-canon-clog.log` 中所有测试套件通过，无失败项；LUTAnalysis 93/93 通过。`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表 Canon C-Log/C-Log2/C-Log3 全机型范围、CP IDT、完整相机策略、`.labin`/直接查表、完整 ICC/HDR、任意三维全根、平台或发布验收完成。
