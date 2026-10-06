# 原生算法数值入口与目录契约复验

## 范围

本轮只复验现有 Swift 算法和注册表入口，不新增曲线、色域、预设、厂商资源或 UI 范围。入口覆盖静态原生边界、独立公式参照、Node 契约、CUBE 生成与读回、格式检查、LUTAnalysis 命令行检查和目录注册表。

## 先失败后修复

首次运行 `Scripts/verify-native-numerics.sh` 的前 66 个并行检查全部通过，但 `LUTCatalogChecks` 因冻结计数仍为 76 条 transfer／20 个色域／72 个预设而失败。当前 `AlgorithmCatalog.builtIn()` 实际目录为 79 条 transfer、20 个色域、75 个预设；稳定 ID、别名、来源、相机 66 项和预设引用检查均保留。

修复 `Native/Packages/LUTKit/Sources/LUTCatalogChecks/main.swift` 的契约计数为 79／20／75，没有删除或新增目录项，也没有改变任何算法实现。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift run --package-path Native/Packages/LUTKit -c release LUTCatalogChecks
swift test --package-path Native/Packages/LUTKit -c debug --filter RegistryContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter RegistryContractsTests
Scripts/verify-native-numerics.sh
```

目录检查结果：79 曲线、20 色域、75 预设、66 个相机身份，稳定 ID／别名／来源、重复和悬空引用拒绝通过，退出码 `0`。

完整数值入口结果：并行静态与公式检查 66 项通过；Node 11 项通过；Swift 契约、格式生成/读回、LUTAnalysis 及项目/任务命令行检查通过；入口退出码 `0`。日志末尾明确为“当前原生子集的静态与命令行契约通过；不等于双端 App 或发布验收”。

修复后的当前 Swift Release 全量回归另外执行 8 个测试包，共 793 项执行、0 失败；`LUTFormats` 的 2 项既有外部夹具仍按设计跳过，`LUTAnalysis` 为 66 项。日志 `full-release-current.log` 的 SHA-256 为 `b4c8866efb07e6d84bdc9eb348a87c91677b4df4b057fc3f8c792e815110f3be`，退出码文件 SHA-256 为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`。

结果包：`artifacts/2026-10-05-algorithm-numerics-gate/`。

SHA-256：

- `catalog-check-release.log`: `e21869fb7c56755b1fad20b8e68d0a3a01d03d95eff160e0d5863849b3ffb093`
- `registry-debug.log`: `02d97843d92a96d0e5b44e83b2bce56db6731c98532778592c163a976d1b7927`
- `registry-release.log`: `d357e45972582ff67c0ed52582e85d32023cfe01d36fababcde1b7e9c27a5dba`
- `verify-native-numerics-rerun.log`: `9cf256cabe256e18c5f091fc0c77fb44ffa4553121402047df021de3e9607a72`
- 本批 `.exit` 文件：`9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

## 未覆盖

本轮不关闭 9 个 `.labin`、45 个直接查表注册、DJI DLog-M、Canon CP IDT、RED DRAGONColor2／IPP2、ARRI SUP2 raw 研究阻塞、PQ OOTF 语义冲突、完整 ICC/HDR/EDR、任意 3D 全局反求、tricubic 反求、真实第三方软件往返、UI、设备性能、签名发布或 `full-scope-acceptance.json`。Goal 保持 `active`。
