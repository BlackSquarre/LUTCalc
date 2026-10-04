# H07/H12 项目资源角色与生成边界阶段验收

日期：2026-09-26。范围：原生 schema v2 的 `other` 资源与 `userLUT` 资源在生成请求、图像取样和导出中的区分。本项不定义用户 LUT 与 19 阶段变换计划的组合顺序；该能力继续单独待办。

## 先失败的契约与修复

- `FileDocument` 与 `EditorSession` 的新契约分别创建带普通 `other` 资源的项目，要求生成请求可创建且设置/数值与无资源项目一致。修复前两处均抛 `userLUTNotInPlan`；失败日志 `/tmp/lutcalc-asset-role-generation-red-20260926.log`，SHA-256 `3f68a19b6a9f2891f2a999699b6b30e20ef5cd88a111211f859b420f78eaf194`。
- `ProjectManifest.userLUTAssetPaths` 按显式 `userLUT`/`legacyUserLUT` 角色识别资源。文档及编辑会话的生成入口仅在这些角色存在时拒绝，普通 `other` 资源不会改变不可变 `TransformPlan`。
- 增加实际导出契约：带 `other` 字节资源的项目经 `NativeExportService` 导出 17³ CUBE，4,913 节点读回，首尾及内部共 5 个坐标与无资源计划比较，最大绝对误差 **0**；资源字节未变。定向日志 `/tmp/lutcalc-h07-other-asset-probes-20260926.log`，SHA-256 `a2909f21d8d29aca1151eb296632caeadc41916d38f0a0508e8e1fc0ee859c65`。
- 五个原生命令行契约原先用名为 `user.cube`、但 schema v2 默认角色为 `other` 的夹具期待“用户 LUT 被拒”。现为这些夹具显式标注 `userLUT`，保留原拒绝断言；没有改动冻结数值预期或放宽门槛。首次完整入口因此在文档取样处退出 1；纠正角色后通过。

## 文件与版本

| 修改文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` | `57755246f903a51670cd550895ab95792030aa6b1ceab3acafa364d5e812ba38` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift` | `f3a703ca58ea5d15350b8964ee57c621e8778811f2c03e320e67db127a20002a` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | `6aacadf2a22fec3b45e4e4d2d12a05a7a215b6609a0bda59bc23197bae389ae3` |
| `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTProjectAssetContractsTests.swift` | `bd76788ce7650371fff47e5e0a29d85a635a21b6392351788a1fe2e98eb909ec` |
| `Native/Packages/LUTKit/Tests/LUTSharedUITests/SessionContractsTests.swift` | `a5cdd22c036c44584b2c5aa8facb5d4f4c07fab9777e0d50f59f5af6055e5ea0` |
| `Native/Packages/LUTKit/Sources/LUTDocumentSampleChecks/main.swift` | `68d260126e68699e4d650ee141359844b4ddfcabcd283bd1ba8f20f8899f8ec2` |
| `Native/Packages/LUTKit/Sources/LUTDocumentExportChecks/main.swift` | `ce4b736ae18ee1c1e4613e58862fecff47e2ec6e276c26e65e64312b8c17df4d` |
| `Native/Packages/LUTKit/Sources/LUTDocumentChecks/main.swift` | `71575bb63cc962986ab885771ffde58de7f4a0a00c9166a51b74cb2bcaea1b2f` |
| `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift` | `e8ebcb073f1d32159329c5236fad9fdc4706d9405e405dbd4ed79df22cd5f184` |
| `Native/Packages/LUTKit/Sources/LUTProjectSessionChecks/main.swift` | `6c52e4f125b37ebd67264bf3b9fba46585432c979b2c5e7629f1615bb833eb15` |

新夹具为上述 XCTest 和命令行契约内的项目资源字节，版本由相应源码哈希锁定；既有 `tests/fixtures/native-contracts/` 与 D-Log2 冻结夹具未修改。本记录和 `docs/native-swift-roadmap.md` 为中文状态文档。

## 实际验证及范围

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4、iOS SDK 27.0，Apple Silicon Mac。

| 实际命令 | 结果 |
| --- | --- |
| `swift test --package-path Native/Packages/LUTKit -c release --filter 'UserLUTProjectAssetContractsTests|SessionContractsTests'` | 修改后 9 项通过，覆盖普通资源快照与用户 LUT 仍拒绝。 |
| `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests.testOtherAssetProjectExportsUnchangedCube` | 实际 CUBE 导出与读回通过，五点最大绝对误差 0。 |
| `bash tools/native-validation/verify-native-release.sh` | 当前源码 246 项 Swift 测试清单，1 项公开 NCP 实样因未给路径按设计跳过；7 个独立公式检查、46 个 33³/65³ CUBE 生成/读回对、原生子集、macOS/iOS Simulator/iOS generic Release 构建与三个 App 包资源审计通过。总退出码 2：真实 `docs/native-validation/full-scope-acceptance.json` 缺失。日志 `/tmp/lutcalc-h07-other-asset-final-release-20260926.log`，SHA-256 `ff8974bb3600c2d09fa2ab05f2cf1dcae02448d37027b7c8a92d3586226933df`。 |

本次证明的是普通项目资源不会改变既有计算或阻止导出，且显式用户 LUT 仍不会被静默略过。用户 LUT 与变换计划的组合语义、更多格式导出、真实 Finder/Files 与 File Provider、双端真机、完整 H07/H12 及发布验收仍未完成。
