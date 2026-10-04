# H12 项目资源角色阶段历史记录（旧 schema 路径已撤回）

日期：2026-09-25。状态：历史记录，仅保留审计索引；旧 schema 读取/升级和旧 App 资源推断不属于当前功能。

## 范围修正

当时曾短暂验证过在原生项目中持久化显式 `assetRoles`。其中按 `schemaVersion=1` 和 `Resources/user-<UUID>.*` 文件名猜测用户 LUT 并升级到 v2 的路径，现已删除。它会把旧项目/旧 App 资产带入新项目，违反当前“不提供旧 App 迁移”的范围决定。

当前规则只有两条：

- schema v2 必须包含与 `assetHashes` 完全对应的显式 `other`/`userLUT` 角色；至多一份 `userLUT`。
- schema v1、未知 schema、缺少 `assetRoles` 或仅凭文件名推断角色均拒绝，不复制资源、不改写源文件、不创建新项目。

## 最新契约

- `ProjectContractsTests.testLegacyNativeSchemaIsNotImported`：旧 schema 直接返回 `unsupportedSchema(1)`。
- `UserLUTProjectAssetContractsTests.testV1PackageIsRejectedWithoutMigration`：旧 schema 的目录包在打开前拒绝。
- `UserLUTProjectAssetContractsTests.testExplicitRoleOverridesFilename`：当前 schema 只服从显式角色，文件名不会改变角色。

详细范围决定和完整回归见[H12 旧 App 设置迁移移除验收](2026-09-25-h12-legacy-app-import-removed.md)。
