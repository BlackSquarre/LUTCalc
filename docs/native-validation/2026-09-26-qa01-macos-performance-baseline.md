# QA-01 macOS Double 性能基线阶段验收

日期：2026-09-26。

## 范围

新增 `LUTPerformanceChecks` Swift 命令行入口，对现有 D-Log2 / D-Gamut2 → 线性 ACES AP0 `TransformPlan` 直接调用 `CubeGenerator.generate3D`，测量 17³、33³、65³ 三种网格的节点数、墙钟耗时、节点/秒和 Double 位模式校验和。它只记录标量 CPU 基线，不改变生成算法、并发策略、网格尺寸、位宽或精度门槛；App 包不包含该研发检查工具或任何夹具。

修改文件：

- `Native/Packages/LUTKit/Sources/LUTPerformanceChecks/main.swift`
- `Native/Packages/LUTKit/Package.swift`
- `docs/native-swift-roadmap.md`

## 实际工具链与命令

主机：`lingrumbp.local`，arm64 macOS；Xcode 27.0（27A266a），Apple Swift 6.4。实际命令：

```text
swift run -c release --package-path Native/Packages/LUTKit LUTPerformanceChecks
```

原始 JSON：`/tmp/lutcalc-performance-macos-20260926.json`，SHA-256：`92e24a71138351e6da4395e1277a10de830685f2af4eed8f124f1450ad8012a5`。

变更后的 `swift test --package-path Native/Packages/LUTKit -c release` 退出码 `0`，日志 `/tmp/lutcalc-qa01-full-swift-release-20260926.log`，SHA-256 `ac093f89996dfd35b1f6773d1881e8125059bebc8a33d20361d320d568fcbb8b`；测试清单仍为 274 项。`bash tools/native-validation/verify-native-release.sh` 的 7 个公式检查、46 对 CUBE 读回、三平台 Release 构建和三个 App 包审计通过，日志 `/tmp/lutcalc-qa01-native-release-20260926.log`，SHA-256 `5ff972e67b8a5caef1ed140dce8239587dc742352b6b9b4d27cc3837a2d9474f`；发布入口因缺少真实全量清单退出码 `2`。

## 结果

| 网格 | 节点 | 耗时（秒） | 节点/秒 | Double 校验和 |
| ---: | ---: | ---: | ---: | ---: |
| 17³ | 4,913 | 0.000252625 | 19,447,798 | `14379552350607772001` |
| 33³ | 35,937 | 0.001571083 | 22,874,030 | `1336097751165010835` |
| 65³ | 274,625 | 0.011861167 | 23,153,286 | `15217861669287451768` |

这是单次 Release 本机基线，不是跨设备性能预算，也不是 iPhone/iPad 实测。当前没有把耗时阈值伪装成发布门槛；后续应在代表性 Mac、iPhone、iPad 固定工作负载下重复并记录峰值内存、取消延迟和批量任务耗时。

## 未覆盖

没有在 iOS/iPadOS 真机或模拟器执行同一 CLI；没有测量整图预览、LUTAnalyst、文件写出峰值、File Provider、后台取消或多窗口。QA-01、QA-02、QA-03、真机性能和发布验收仍未完成。

## 2026-09-27 基线复跑

同一主机和 Release 工具链再次执行：

```text
swift run -c release --package-path Native/Packages/LUTKit LUTPerformanceChecks
```

退出码 `0`；原始 JSON `/tmp/lutcalc-performance-macos-20260927-rerun.json`，SHA-256 `c67502ee1d4066bf69d22a4a5615311487beed8e2e968abbdc08b08ef74f490b`。三组 Double 位模式校验和与 2026-09-26 基线完全一致：17³ `14379552350607772001`、33³ `1336097751165010835`、65³ `15217861669287451768`。本次墙钟耗时分别为 `0.000269666`、`0.001603709`、`0.012269583` 秒；与首次单次基线的差异属于同一主机运行波动，不能解释为性能提升。
