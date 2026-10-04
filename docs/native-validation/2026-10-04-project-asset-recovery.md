# 2026-10-04 项目外部资产恢复协调验收

## 范围

本轮补齐项目外部用户资产在文稿重开或提供商生命周期边界后的纯 Swift 恢复协调。它不把本地契约当作真实 iCloud/File Provider 证据，也不修改项目包内自包含资源、Double 计算或导出格式。

## 先行契约

新增 `ProjectAssetRecoveryContractsTests` 四项：

- 可解析且内容哈希一致时，书签优先并报告来源；
- 书签解析成功但文件内容被替换时拒绝，不能回退到其他候选；
- 无效书签可在调用方已授权目录内按 SHA-256 和原始文件名重发现；
- 没有书签和授权目录时返回显式 `noAuthorizedSource`。

先行测试在实现前因 `ProjectAssetRecovery` 不存在而失败；实现后 Debug 定向 4 项通过，Release 定向 4 项通过。

## 实现边界

`ProjectAssetRecovery.resolve` 先解析书签并重新计算 regular file SHA-256；解析成功但内容不符时返回 `contentChanged`。只有书签解析失败时，才允许使用调用方明确提供的 `authorizedRoots` 进行 `ProjectAssetDiscovery`；发现结果不保存外部授权凭据，stale 书签由已有 `renewedIfStale()` 生成替代值。

## 构建与结果

- Swift Release 全量回归退出码 `0`；`ProjectAssetRecoveryContractsTests` 4 项通过，原有包结果均保存在结果日志。
- macOS generic Release 构建退出码 `0`。
- iOS generic Release 构建退出码 `0`。
- 当前源码以开发签名在实体 iPhone 11（UDID `00008030-001015101ABA802E`）Release 构建、安装和启动均成功；进程 PID `960`，退出码均为 `0`。这只证明恢复协调代码进入真机 App 包并可启动，不等于真实 provider 恢复通过。
- 结果包：[artifacts/2026-10-04-project-asset-recovery](artifacts/2026-10-04-project-asset-recovery/)。

## 未覆盖范围

- 没有真实 iCloud/File Provider URL、授权撤销、跨进程 provider、stale bookmark 系统替换或后台终止后的实体设备证据。
- `authorizedRoots` 必须由平台调用方在用户授权后提供；本协调层不会自行扫描未授权目录。
- 没有把本地恢复契约解释为 iPhone 11 后台恢复、iPad 文稿协调或发布验收。
