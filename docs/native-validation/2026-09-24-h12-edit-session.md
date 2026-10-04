# H12 项目编辑会话阶段验收

日期：2026-09-24。状态：阶段通过，H12/APP-04 尚未完成。

## 契约与实现

在现有 `.lutcalc` 严格包格式之上增加纯 Swift 值类型 `ProjectEditingSession`。它保存完整的当前 `ProjectManifest`，提供不可变快照、撤销/重做、修订号、脏状态、新建保存、原址保存和“另存为”。编辑前仍经 `ProjectCodec` 校验；项目 ID 不匹配明确拒绝。比较编辑状态使用规范编码后的字节，因而 `-0.0` 与 `+0.0` 不被 `Double ==` 合并。原址保存携带打开时的 `manifest.json` 原始字节作为冲突条件；另存为从旧包携带未改变的用户资源并再次校验哈希。旧包不删除。

## 修改文件与当时版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectEditingSession.swift` | 完整清单的编辑、历史、保存与资源复制 | `4fbe2b7fd40cca9ae69b9805637b3ed0ed7a64a498c2ad188122b668127568df` |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` | `saveExisting` 增加可选原始清单字节冲突检查 | `9bb8388a52fb9c7fd2e84ddb1a591177c7eb5b678ba698a461e019af64426531` |
| `Native/Packages/LUTKit/Sources/LUTProjectSessionChecks/main.swift` | 符号零、撤销/重做、两窗口冲突和资源另存为契约 | `7262bba86229dbef525011d2d924e7526d1329d4341018139532bcc781483840` |
| `Native/Packages/LUTKit/Tests/LUTProjectTests/ProjectContractsTests.swift` | 对应 XCTest；待完整 Xcode 运行 | `307c15efd1dc059628221323a77eb8216783adcf6d7187410c4c579d8b5b4e0e` |
| `Native/Packages/LUTKit/Package.swift` | 增加契约 target | `2ba600a0829fbb07bb8f328cbc9c80b7db7a36d614e0242b980b11c77cedc8de` |
| `tools/native-validation/verify-native-subset.sh` | 将新契约纳入 Release 验证 | `d5e659acf9a742070fc93050944eccbff0e41549017199e72b7e30e3bce34d00` |

## 实际验证

- Apple Swift 6.2.1，arm64 Command Line Tools；现有 `AlgorithmCatalog` 与项目包实现作为源版本，未改冻结数值夹具。
- 先写 `LUTProjectSessionChecks`，`swift build --package-path Native/Packages/LUTKit --product LUTProjectSessionChecks` 按预期因 `ProjectEditingSession` 不存在而失败；随后实现。
- `swift run --package-path Native/Packages/LUTKit LUTProjectSessionChecks` 退出码 0。验证 `0.0` 与 `-0.0` 的 `bitPattern` 在编辑、撤销、重做、保存读回中各自保持；两个窗口从同一包打开后，先保存的窗口把符号零改回正零，后保存的窗口收到 `concurrentModification`，其编辑状态和磁盘文件均未丢失。带用户 CUBE 资源的包在原来源文件删除后仍可另存为，并在原包删除后独立打开、资源字节完全一致。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h12-session-validation-20260924.log 2>&1` 退出码 0；静态边界检查覆盖 39 个 Swift 源文件，旧引擎 Node 9 项通过，既有数值、CUBE、项目、预览、任务和会话契约通过，新项目编辑会话在 Release 执行通过。

## 未覆盖范围

当前是项目模型层；原生草稿界面尚未接入打开/保存与系统 `DocumentGroup`，多窗口 UI/Files/File Provider 和真机验证未执行。原址替换最后的外部竞争窗口及文件协调仍需平台验证。旧网页 JSON 会被拒绝且不属于原生输入；原生项目 schema 按当前契约独立校验。完整迁移与发布门槛均未通过。
