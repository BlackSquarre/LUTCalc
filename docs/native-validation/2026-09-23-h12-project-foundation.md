# H12 项目包基础阶段记录

日期：2026-09-23。此阶段建立纯 Swift 的版本化项目清单、本地新建/打开事务与用户资源自包含；项目 UI、旧版本迁移与文件提供者尚未实现，故 H12 不算完成。

## 契约与实现

先新增 `LUTProjectChecks`，冻结以下行为：设置与 Double 位模式完整往返；未来 `schemaVersion`、未知根/设置字段、未知算法 ID 明确拒绝；新建包移动后仍能打开；已有包拒绝覆盖并保持原字节；两份项目互不污染。首次运行先因项目类型不存在而编译失败，随后实施 `ProjectManifest`、`ProjectCodec` 和 `ProjectStore`。资源子项也先加失败测试，再实施 SHA-256 流式复制与打开校验。

`.lutcalc` 目前是包含 `manifest.json` 的目录包。清单保存 `schemaVersion`、`engineVersion`、`registryVersion`、项目 UUID、`algorithmVersions`、完整 `TransformSettings`、网格尺寸与域、`assetHashes`。保存使用 JSONEncoder 的 Double 表示，不经过 UI 格式化；解码先预检未知字段与规范 ID，再通过当前注册表和 `TransformPlan` 校验，避免找不到条目时套用首项。保存新项目在同目录新建本任务临时包、写入并读回验证后移动到目标；目标已存在即拒绝，清理只涉及本任务临时目录。

实际命令：

```text
swift run --package-path Native/Packages/LUTKit LUTProjectChecks
swift run -c release --package-path Native/Packages/LUTKit LUTProjectChecks
swift build -c release --package-path Native/Packages/LUTKit
swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
swift run -c release --package-path Native/Packages/LUTKit LUTContractChecks tests/fixtures/native-contracts/numeric-contracts.json tests/fixtures/dlog2-reference.json tests/fixtures/native-contracts/parser-contracts.json tests/fixtures/native-contracts/first-chain-reference.json tests/fixtures/native-contracts/srgb-reference.json tests/fixtures/native-contracts/srgb-legacy-reference.json tests/fixtures/native-contracts/srgb-plan-reference.json
swift run -c release --package-path Native/Packages/LUTKit LUTSessionChecks
swift run -c release --package-path Native/Packages/LUTKit LUTJobChecks
swift run -c release --package-path Native/Packages/LUTKit LUTAnalysisChecks
swift test --package-path Native/Packages/LUTKit
```

前八条命令通过。项目契约包含 `0.1`、`0.18.nextUp`、负零、`-1e-300`、`100.00000000000001` 等曝光 Double 位模式，扩展域、12 位设置、未知根/嵌套字段与未知 ID、拒绝用户资产伪支持、移动后打开、覆盖保护、双文档隔离。`swift test` 实际失败，错误为 `no such module 'XCTest'`；本机只有 Command Line Tools，不能把新增 XCTest 文件计为已通过。此前数值、任务、分析和会话的 Release 契约入口回归均通过。

当前修改文件及 SHA-256：`LUTProject/ProjectManifest.swift` 为 `1d8e83111296b0420f1adaf6295ad2a8d2a93fc71b4dfafea359733a7616e0bd`；`LUTProjectChecks/main.swift` 为 `56dca70ce4b0d49f194f1fa02d8435c66f392af94767e193c9e2bfb8a8ce85de`；`LUTCore/NumericTypes.swift` 为 `a20f5a12b2f8d6307c2ae80113174bbd8015b674e8a69b2df48fe46d4fbe1df0`；`LUTCore/TransformPlan.swift` 为 `229009008ded20446ccf673af0c9120676627c11238d942933c6e688d7bcd294`；`Package.swift` 为 `7302fe30288fbcb060a3dc4823993528f6216c308f08389202762e73fba36cec`。另增 XCTest 文件 `Tests/LUTProjectTests/ProjectContractsTests.swift`，尚未运行。

## 第二段：用户资源自包含

`ProjectAssets` 只接受 `Resources/<单个文件名>` 的相对路径和 64 位小写十六进制 SHA-256；采用 Apple CryptoKit 和 1 MiB 分块，单资源上限 256 MiB。保存时从调用方提供的用户资源 URL 复制到本任务临时包并同步计算摘要，和清单不符则拒绝提交。打开时拒绝额外、缺失、哈希不符的资源，并拒绝包、资源目录、清单和资源文件的符号链接。研发契约使用真实 1D CUBE 字节，其独立 `shasum` 参照为 `71a4b822c702424a0d1d77d02abad109f0bc5ee5652b0a60c15656f58691fdd8`；移动项目包且删除源文件后仍能打开并读回原字节。篡改文件、缺少来源、错误预期摘要、路径穿越和符号链接均被拒绝；失败保存没有留下目标包。Debug/Release `LUTProjectChecks`、Package Release 构建及 `LUTSessionChecks` 再次通过。

## 未覆盖与风险

当前支持新建含用户文件副本的项目包，资源 URL 的安全作用域访问、外部引用重定位及项目版本迁移链尚未实现。未知新版本选择拒绝而非只读；原文件保持不变。没有 `DocumentGroup`、UTType 声明、Finder/Files/iCloud/文件提供者访问授权和已有项目修改/覆盖事务；这些均属于 H12/FLOW-04 后续验收。目录包的本地移动测试不能推断跨设备可移植性。macOS/iOS `.app` 构建与真机项目操作仍未验证。
