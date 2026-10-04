# H12 原生项目清单版本审查（严格拒绝旧 schema）

日期：2026-09-24，2026-09-25 更新。结论：原生项目不提供旧 schema 升级；当前只接受 schema v2，旧 schema 和旧 App 设置均拒绝。本段保留审计背景，不构成迁移功能。

## 已有版本与拒绝策略

- `ProjectManifest.currentSchema` 当前为 `2`；`currentEngine` 为 `native-minimal-v1`，`currentCatalog` 为 `catalog-minimal-v1`。构造新清单时只写入 schema v2 与显式 `assetRoles`。`ProjectCodec.decode` 要求三项版本精确匹配，否则以 `unsupportedSchema`、`unsupportedEngine`、`unsupportedCatalog` 拒绝；未知字段、缺失角色和算法 ID 另行拒绝。
- 历史实样 `docs/native-validation/artifacts/2026-09-24-mac-roundtrip.lutcalc/manifest.json` 保留作审计材料，不再是当前可打开输入。`ProjectContractsTests.testSettingsDoubleAndUnknownVersion` 冻结未知 schema 拒绝，新增旧 schema 拒绝契约覆盖 schema v1。
- `TransformSettings` 对缺失 `settings.adaptation` 的兼容读取只适用于同一当前清单的可选字段；它不创建旧 schema 迁移，也不推断资源角色。
- 当前 Git 仓库没有可解析的 `HEAD`，无法从提交历史恢复某个更早的原生清单版本。旧网页 `.lutcalc` 是单文件 JSON，字段为 `version` 与各 UI 分区，不是原生目录包的前一版 schema；其导入仍有大量未映射字段。

## 缺失的迁移依据

没有足够证据支持旧 schema 升级；按当前范围直接拒绝比猜测字段含义更安全。旧 App JSON、schema v1 以及按文件名推断用户 LUT 的输入均不转换、不复制、不改写。

## 可执行下一步

若未来重新提出版本兼容需求，必须先由用户单独确认范围，再建立新的来源、字段语义和数值证据；在此之前保持 schema v2 严格拒绝路径。
