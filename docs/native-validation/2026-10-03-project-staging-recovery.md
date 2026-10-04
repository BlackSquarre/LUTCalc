# 项目 staging/backup 孤儿回收非 UI 阶段验收

日期：2026-10-03

## 范围

为项目存储补充 `ProjectStore.recoverOrphanedStaging`、`recoverOrphanedBackups` 和 `recoverOrphanedTemporaryEntries`，处理进程中断后遗留的 `.lutcalc-*.staging`／`.lutcalc-*.backup` 目录及 `.lutcalc-*.tmp` 临时条目：

- 只扫描目标目录的隐藏 staging/backup 名称；
- 只删除真实目录，拒绝符号链接；
- 只删除超过调用方年龄阈值的目录，保留新目录和 `.tmp` 及非 UUID 命名条目；
- 目录不是有效项目父目录或年龄阈值非法时明确返回 `ProjectError.invalidPackage`；
- `.tmp` 回收同时允许目录和普通文件，仍拒绝符号链接；
- 不改变保存、替换、项目 manifest 或生成数值路径。

## 契约与实现

先添加 `ProjectStagingRecoveryContractsTests`，覆盖旧 staging/backup 的精确删除、新条目／无关目录保留和负年龄拒绝；先行编译失败因为接口尚不存在。随后补充 `.tmp` 文件／目录、符号链接和项目打开恢复契约；当前 Debug/Release 定向各 6 项通过。

## 实际验证

工具链：Xcode 27，Swift 6，macOS 27 SDK，Apple Silicon arm64。

```text
swift test --package-path Native/Packages/LUTKit --filter ProjectStagingRecoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ProjectStagingRecoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-project-transaction-recovery-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-project-transaction-recovery-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-project-transaction-recovery-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

结果：

- 初始 staging/backup 定向各 3 项，后续 `.tmp` 回收定向各 5 项，再加入打开恢复后当前定向各 6 项，均为 0 失败；
- 打开恢复接入后的 Release 全量为 572 项，0 失败；LUTFormats 的 `.labin` 与 NCP 外部夹具各 1 项按设计跳过；
- macOS、iOS generic、iOS Simulator 未签名 Release 构建退出码均为 0，App 包实际生成；
- 三个 App 包未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m` 或 `.mm` 资源。

日志 SHA-256：

```text
Debug 定向       74ff18d34903542608f9bea8cd2de1885cf8c98b7287846da54955d6e50c6ee7
Release 定向     98e4a4a89cb556d4cde83d96e88ae72ec42ff7a936d55f07bb372e50d0634606
Release 全量     706af5a5f05ec1f9509920e7d2f2c6b2111bb57c5dd5a2145c2afadb5d8264a1
macOS 构建       095722a5b0f02648f06021a82e779cc58f80227d0c3086063e013c46b5854c82
iOS 构建         c00af7eeeff2adca38d83432283c8f746d9b717cf46a50dc7c6f6877b7484458
模拟器构建       9510a1331f3688e0c7e0e22c24d9a84bd91523998372c29eacf2048986214c42
```

## 未覆盖范围

本轮只覆盖本地项目 staging/backup/temporary 回收契约，不证明真实 iCloud/File Provider 授权失效、外部目标替换竞争、磁盘故障、真实后台恢复、Finder/Files 交互或多进程提供商行为。导出 sink 的跨进程孤立临时文件清理调用尚未接入启动路径；签名发布、性能预算和 `full-scope-acceptance.json` 仍未完成。

## `.tmp` 回收补充

先行契约命令第一次按预期编译失败：接口尚不存在。实现后实际运行：

```text
swift test --package-path Native/Packages/LUTKit --filter ProjectStagingRecoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ProjectStagingRecoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-tmp-recovery-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-tmp-recovery-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-tmp-recovery-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

- Debug 定向实际执行 5 项，0 失败；Release 定向实际执行 5 项，0 失败。
- 在接入打开恢复前，Release 全量日志中的 XCTest case 均无失败，实际计数 571；LUTFormats 的既有 `.labin` 与 NCP 外部夹具按原契约跳过。打开恢复后的 572 项结果见下节。
- 三个平台命令均打印 `EXIT_CODE=0`，并生成以下 App：
  - `/tmp/LUTCalc-tmp-recovery-mac-20261003/Build/Products/Release/LUTCalcMac.app`
  - `/tmp/LUTCalc-tmp-recovery-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app`
  - `/tmp/LUTCalc-tmp-recovery-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`
- 三个 App 包均未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm` 或 `.labin` 文件。
- 构建日志 SHA-256：Debug `6483d97b7d20840ba9d78db41a0d1c0227014c5c0545adb3f8a0793c5b2dd041`；Release 定向 `cd0745bce7df00f5643e4ae85a15439529a2c0c54019cb8388319bf00d015756`；Release 全量 `562a24e54d23a6c687a2b62365aef1cd8d5c6ce018500f8ee54174da387bbc2d`；macOS `84564a0d283fc35aac5853bb7a20786d183534eebcebdb5eb8e35eddd145e39e`；iOS `8b0b358e49fadab586f364f113d75ac7894a0f6073a57c7c8112fbe041fad285`；模拟器 `5ec47f3ee3fb285bd3c21998b1b2b215bc0c0d36a00a3da193aee9d021590853`。

## 打开项目时的自动恢复补充

`ProjectEditingSession(opening:)` 现作为非 UI 恢复入口，在读取 manifest 前，以 `ProjectStore.defaultOrphanRecoveryAge == 3600` 秒为宽限期，尽力调用 staging、backup、temporary 三类回收。回收错误被隔离，不会遮蔽项目本身的打开错误；同目录中仍在使用的新条目和符号链接保持不变。

先添加打开恢复契约后，接口缺失导致编译失败；实现后实际结果：

- Debug 定向 6 项，0 失败；Release 定向 6 项，0 失败；Release 全量 572 项，0 失败。
- macOS、iOS generic、iOS Simulator Release 构建均退出码 0，并生成对应 App 包；此次构建日志 SHA-256 分别为 `e20663c4640f151f00ec55991c8f8ba2c8de063e7b41b2c3813223fee3ba0936`、`5eeb0ba27aa37a82ad4124af3fe7ae12d28acaaae56fb9fd1f999308cc841801`、`204d6db0dad46fcdcb930a1b765a24607c9a96b795a94ae03f6a4c80a167268e`。
- 三个 App 包未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm` 或 `.labin` 文件。
- 本补充仍不证明真实 iCloud/File Provider 授权失效、跨进程提供商行为、磁盘故障或 iPhone 11 后台恢复；Goal 保持 active。

## 保存边界自动恢复补充

`ProjectStore.saveNew` 和 `saveExisting` 现会在创建本次临时包／替换 staging 前，以同一 3600 秒宽限期尽力回收同目录旧 staging、backup 和 tmp。新项目首次保存不再依赖先打开项目才能清理孤儿条目；回收仍是 best effort，不改变目标存在、并发修改或项目校验错误。

契约 `testSavingNewProjectPerformsSiblingRecoveryBeforeCreatingTemporaryPackage` 先验证旧 `.tmp` 会被保留，随后实现后通过。当前结果：

- Debug 定向 7 项，0 失败；Release 定向 7 项，0 失败；Release 全量 573 项，0 失败（两个既有可选夹具跳过）。
- macOS、iOS generic、iOS Simulator Release 构建均成功并生成 App；模拟器构建使用独立 derived data 路径 `/tmp/LUTCalc-save-recovery-sim2-20261003`，避免先前并行构建留下的数据库锁。
- 三个 App 包均未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm` 或 `.labin` 文件。
- 日志 SHA-256：Debug `24dd902a4c2d369721e52cef00f0a619bd32cbb161f90f7c2b4f913d9a1281ec`；Release 定向 `98abbe7689a06ae794e3db3cf5db0a1e83ce641ccb76aa4e6c8d9d7714581e5c`；Release 全量 `7fc6d1d800746ece5620dfa77fde549921298a882a297dfb5f5ffc3513a001d4`；macOS `490cab31931ddc364b65682b5b07c7073934945b67c679a32c7f622b3529337c`；iOS `ff921fdf535a6451a132198ee98aaa0a05e60d8bcf91a4cb928e9eaa8bb7b4d0`；模拟器 `23938e959a75c461811bbf12ef286aca73b83588a7348f81d1b8eba332c143c2`。
- 仍未覆盖真实 File Provider/iCloud 事务、跨进程清理竞态、磁盘故障和设备后台恢复。

## 导出启动恢复补充

`ProjectExportSession.start` 现在在创建导出请求前，调用同一 3600 秒宽限期的 `.tmp` 回收策略，覆盖系统临时目录中被进程终止遗留的导出 sink 临时文件。该调用是 best effort，不改变导出请求取消、后台挂起、晚返回隔离或已完成输出保留语义。

先添加 `testStartingExportRecoversOldSiblingTemporaryFiles`，在实现前按预期失败；实现后结果如下：

- Debug 定向 7 项，0 失败；Release 定向 7 项，0 失败；Release 全量 574 项，0 失败。
- macOS、iOS generic、iOS Simulator Release 构建均成功，App 包禁用资源审计通过。
- 日志 SHA-256：Debug `9b9eec548bbfa1087941dd94708e36f63238de80b60acc9897d370232426057e`；Release 定向 `c71cb3dd6b069ea26a26faeea85cb1a47c8caa8b00b9c7c2f44e49e45ff740d1`；Release 全量 `7aad9e8d20053113d9074f8424414de6056c676fd8c25f76093191d95a143e58`；macOS `358de056066ede70f8ad40d98bcb377fbdd372a8ed7415cc56b69455c54c2f27`；iOS `5a5a1aed768aeaf4a0d579c350597a8bc2ad7690ddc168dc154bcd7841295ec7`；模拟器 `a532e347a0a2eeb1107b362fb739b16975285b4c6dad4f63ea01e1c59d33c10e`。
- 真实 iCloud/File Provider、跨进程清理竞态、磁盘故障、iPhone 11 后台恢复和发布签名仍未覆盖。
