# H07 用户 LUT 与其他项目资源共存阶段验收

日期：2026-09-25。范围：修正 `.lutcalc` 中任意资源都被误判为“已有用户 LUT”的行为，保留项目包原有其他资源及内容哈希。

## 先失败契约

新增 `UserLUTProjectAssetContractsTests.testImportedLUTCoexistsWithUnrelatedProjectResource`：先构造带 `Resources/reference.cube` 的合法项目资源，要求它不被当成已导入用户 LUT；随后主动导入另一份 CUBE，要求两份资源及哈希均保留、`FileWrapper` 重开后只列出新用户 LUT，且旧资源不能通过“项目内用户 LUT”入口解析。Release 定向运行先失败：旧实现将所有资源列为用户 LUT，并抛 `projectAlreadyHasAsset`；日志 `/tmp/lutcalc-user-lut-coexist-red.log`，SHA-256 `ab391148c21cb0c5950fd9722d22b768faee243255ed8145dc46475c5a62e5fd`。

## 修正与结果

- 仅将当前清单显式标记为 `userLUT` 的资源列为项目内用户 LUT。文稿内当前仍只允许一份用户 LUT；其他资源可共存，原字节和 SHA-256 均保留。
- `storeImportedUserLUT` 在既有清单与资产字典上追加，继续校验全部内容并递增修订；`inspectStoredUserLUT` 对非该命名约定的资源明确拒绝。
- `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests`：3 项通过、0 失败；日志 `/tmp/lutcalc-user-lut-coexist-green.log`，SHA-256 `438aeaa46a26a3e94a40cd2a1b236b6fdc2d33133f8bd9dc6c2a2da7d09b65f2`。

当前项目清单只接受 schema v2 的显式资源角色；旧 schema 和 UUID 文件名推断均拒绝。生成计划对任何带资源项目继续明确拒绝，用户 LUT 尚未参与生成。系统文稿交互、Files/File Provider 和真机仍未验收；H07/H12、FULL-05 与发布门槛保持未完成。
