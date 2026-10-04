# ILUT/OLUT 输入域符号零边界阶段验收

日期：2026-09-25。范围：固定单位输入域的 ILUT、OLUT 1D 原生导出。状态：**定向契约与当前完整回归通过；完整格式迁移和发布门槛仍未完成。**

## 问题与契约

这两种整数文件不能记录输入域。既有格式 writer 用 `Double.bitPattern` 要求输入域精确为正零到一；但导出服务和文件 sink 准备阶段此前只用 `LUTDomain == .unit`，会把 `-0.0` 当成 `0.0`。这使前置可表示性判定与最终 writer 不一致，也可能在完整生成后才报错。该边界不改变采样算法、14/12-bit 量化或冻结误差门槛。

先新增三项契约：ILUT 与 OLUT 服务各自拒绝单通道负零域且不创建目标；两个文件 sink 在 `prepare` 阶段拒绝负零域。首次 Release 定向运行：服务两项失败，文件 sink 契约中两次拒绝均失败；日志分别为 `/tmp/lutcalc-1d-signed-zero-red-20260925.log`、`/tmp/lutcalc-1d-signed-zero-sink-red-20260925.log`。

## 实现与已完成验证

服务和两个 sink 的前置检查统一使用既有 `AssimilateLUTWriter.isExactUnitDomain` 位模式判断，与 ILUT/OLUT writer 的单位域要求一致。在生成或创建暂存文件前拒绝不可表示的负零域，不进行隐式归一化。

`swift test -c release --package-path Native/Packages/LUTKit --filter 'testServiceRejectsNegativeZeroUnitDomain|testOneDIntegerSinksRejectSignedZeroDomainAtPrepare'` 退出码 0；3 项 XCTest、0 失败。日志：`/tmp/lutcalc-1d-signed-zero-green-20260925.log`。工具链：Xcode 27.0（27A266a）。

最新源码执行 `bash tools/native-validation/verify-native-release.sh`：旧 Node 11 项、Python 审计契约 3 项、Swift Release XCTest 120 项（8 个测试目标）均通过；macOS、iOS Simulator、iOS generic 三个 Release 构建及三个 App 包资源审计通过。日志 `/tmp/lutcalc-1d-signed-zero-release-20260925.log`。入口最终退出码 2，原因是缺少真实全量发布清单 `docs/native-validation/full-scope-acceptance.json`；没有创建或补造该清单。

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | `2acb232645abedac2a29bc40eebc18128368caa12b2a5b4b59c0fdd9f2875afa` |
| `Native/Packages/LUTKit/Sources/LUTJobs/FileILUTSink.swift` | `fe89fbbb210e179c5dff66c7ec0eb8f6ffd85a4ceda348c76cd9e4dc03089c13` |
| `Native/Packages/LUTKit/Sources/LUTJobs/FileOLUTSink.swift` | `2bec31321f18cf36c21c40ab70491348d1f0bf334af3cc653da5b46682e551f6` |
| `Native/Packages/LUTKit/Tests/LUTSharedUITests/ILUTServiceContractsTests.swift` | `729eba373b7ee50c1dbbb647b839fa81adc89d511bfca1d777b5810f96af0b0e` |
| `Native/Packages/LUTKit/Tests/LUTSharedUITests/OLUTServiceContractsTests.swift` | `1d637774d6e194b6f3f53de1c04654bc4571d1ac5ef7c5269a18c1a7be47a9be` |
| `Native/Packages/LUTKit/Tests/LUTJobsTests/ILUTExportContractsTests.swift` | `78cecebdb202033e29f5d0667aa9c4a202353d7265162f62cc57b88b48f1a29e` |

## 未完成

系统 Files 的独立读回和取消、目标软件导入、其余格式/方言和 FULL-06 仍未完成。此项只关闭已支持整数 1D 子集的输入域位模式一致性。按用户 2026-09-25 最新安排，后续真机测试集中到最后执行，不因当前设备镜像连接不稳定重复打扰用户。
