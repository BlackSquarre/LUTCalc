# H08 本地目标边界与文件身份竞争阶段验收

日期：2026-09-25。范围：补齐本地导出在创建临时文件前的目标父目录检查，并收窄显式覆盖的竞争窗口。本段只覆盖当前本地文件系统；不把检查推广为 File Provider、iCloud、系统分享面板或真机证据。

## 先失败契约

新增 `FileDestinationContractsTests`，要求父路径是普通文件或只读目录时，`prepare` 明确失败，sink 保持 `idle`，且不能遗留 `.lutcalc-` 临时文件。另保留已有 `LocalCommitRaceContractsTests` 的等字节新 inode 竞争契约：显式覆盖在 `validate` 后目标被删除并以相同字节重建时，必须返回 `targetChanged`，不替换竞争方。

实现前新增目标边界契约因 `FileSinkError` 缺少明确错误枚举而失败；显式覆盖契约也暴露原实现仅比较 SHA-256、会接受等字节新文件身份的问题。

## 实现与定向验证

- `LocalFileCommit.preflightDestination` 统一检查目标父路径存在且为目录，并检查本地可写性；CUBE、SPI3D/3DL/VLT、SPI1D、ILUT、OLUT 和 Assimilate 1D sink 在创建临时文件前共用该检查。
- 新增 `destinationUnavailable` 与 `destinationPermissionDenied`，错误不会创建临时文件。
- `LocalFileCommit.fingerprint` 现在组合本地 `systemNumber`、`systemFileNumber` 与 SHA-256；显式授权覆盖遇到等字节但新 inode 的竞争方会返回 `targetChanged`，保留竞争方字节。
- 未改变 Double 生成、节点顺序、量化规则或 File Provider 行为；File Provider 权限/版本协调、系统保存提交、断电持久性和真机取消仍需独立验收。

定向 Release 验证：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --package-path Native/Packages/LUTKit -c release \
  --filter FileDestinationContractsTests
```

2 项通过。随后：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTJobsTests
```

LUTJobsTests 共 30 项通过；日志 `/tmp/lutcalc-h08-file-boundary-final.log`，SHA-256 `edcf6d4d62ee86ce8eaf3c076c8aecff53c9db6b1786b44b4e9fb6e442f6c07b`。

## 验收结论与未完成边界

本段证明本地父目录和显式覆盖文件身份的最小边界，不能勾选 H08、FLOW-02 或 QA-02。File Provider/security-scoped URL 的实际授权、云文件协调、最终替换原子性在提供商语义下、系统分享后的保存提交、真机取消和设备内存/磁盘预算仍未验收。
