# H12 已有项目的本地修改事务

日期：2026-09-23。接续[项目包基础记录](2026-09-23-h12-project-foundation.md)。本步增加纯 Swift `ProjectStore.saveExisting`，允许在保留项目 UUID 与用户资源的前提下修改已有 `.lutcalc` 目录包。UI 仍是草稿，没有加入详细项目界面。

## 契约与实现

先在 `LUTProjectChecks` 写入以下契约：修改已移动项目后，设置及 `Double.bitPattern` 精确读回；调用方持有的旧快照过期时拒绝保存；新清单 UUID 不一致时拒绝；已有自包含用户 LUT 在原导入源文件已删除后仍能随项目修改保留；新资源哈希错误时不改变原项目，且不留下本任务暂存目录。首次 Debug 构建退出码 1，报缺 `saveExisting`、`concurrentModification` 和 `projectIdentityMismatch`。

实现采用 `saveExisting(document, replacing: expected, at: ...)`：先严格打开和核对旧项目，再把未修改的用户资源从原包复制到新暂存包；新资源仍必须由调用方给出来源。新包复用 `saveNew` 的清单/资源哈希验证。提交前再次打开旧项目并核对清单原始字节，检测大部分并发修改；随后调用 Foundation [`FileManager.replaceItemAt`](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29) 替换同目录包。替换时保留一个本任务命名的旧包备份，只有新包重新打开并与目标清单一致后才尝试移除备份；替换尝试抛错时不清理可能包含恢复数据的暂存包。此本地策略不替代平台文件协调，最终核对与替换之间仍有竞争窗口。

## 实际运行与结果

```text
swift run --package-path Native/Packages/LUTKit LUTProjectChecks
tools/native-validation/verify-native-subset.sh
```

两条命令最终退出码 0；子集入口包含 Swift Release 构建及 Release `LUTProjectChecks`，旧 JS 测试 9/9，静态原生扫描 35 个 Swift 文件。测试还保持原有未知字段/算法版本、移动包、双文档隔离、资源篡改与符号链接拒绝契约。新增失败更新检查确认：原 `manifest.json` 字节不变、旧项目仍可打开、临时根目录中没有 `.lutcalc-` 暂存包。新增源码没有把用户 LUT、旧 `.labin` 或测试夹具加入 App。

修改源码 SHA-256：`Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` `bfaeb3a2d7276f29b58bac94e819d7c228a12b357ec107321e569d4681d1353f`；`Native/Packages/LUTKit/Sources/LUTProjectChecks/main.swift` `0a5e5d30bc56b3faa4e5d7f98ec67648fef259440db2ec27febfcde9b49ac7c3`。沿用 H12 原项目与用户 CUBE 夹具，未更改数值网格、位宽、插值或误差阈值。

## 未覆盖

当前原生项目只接受 `schemaVersion = 2` 和显式资源角色；schema v1、旧网页设置导入及按文件名猜测角色均拒绝，不做 `v1→v2` 升级。DocumentGroup/UTType、Finder/Files/iCloud/File Provider 安全作用域和协调、替换 API 自身失败后的真实平台恢复，以及最终核对到替换的竞争控制仍待完成。本机无完整 Xcode/iOS SDK；XCTest、macOS/iOS/iPadOS `.app`、模拟器、真机及发布门槛没有通过。H12/APP-04/FLOW-04 仍仅部分完成。
