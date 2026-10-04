# H07 用户 LUT 项目资产保存与重开阶段验收

日期：2026-09-25。范围：用户在原生文稿草稿中主动选择 LUT 后，将所选文件的原始字节加入 `.lutcalc/Resources`，保存并重开项目后继续做只读数值检查。本阶段没有把该 LUT 接入变换或生成计划。

## 先失败的契约与实现

先新增 `UserLUTProjectAssetContractsTests`，要求系统导入所得原始字节进入文稿、清单记录 SHA-256、项目包写盘后删除原导入文件仍可重开并直接取样；篡改包内资源必须拒绝，带资源的项目必须继续拒绝生成。未实现时运行 `swift test --package-path Native/Packages/LUTKit --filter UserLUTProjectAssetContractsTests`，编译因缺少 `storeImportedUserLUT`、`inspectStoredUserLUT` 失败，日志 `/tmp/lutcalc-h07-asset-red-20260925.log`。

导入器现在在 security scope 有效期间分块读取原始文件，累计字节数受项目资源 256 MiB 上限约束，并用同一份字节解析已支持的八种用户格式。文稿只接受有原始字节且可再次解析、解析结果与会话中 LUT 一致的主动导入结果；不一致时拒绝修改文稿。资产使用生成的安全资源名写入 `Resources`，记录内容 SHA-256。当前每个文稿只接收一份用户 LUT；已有资源时导入按钮禁用。添加资产时清空旧编辑撤销/重做记录并递增修订，关闭旧导出会话，以免旧结果被展示为新项目状态。重开时先由既有 `FileDocument` 哈希检查验证资产，再从包内字节解析和只读取样；不依赖原始外部 URL。界面明确显示“目前不参与生成”，`makeGenerationRequest` 的 `userLUTNotInPlan` 拒绝保持不变。

## 结果与边界

| 命令 | 结果 |
| --- | --- |
| `swift test --package-path Native/Packages/LUTKit --filter 'UserLUT(ProjectAsset\|Import)ContractsTests'` | Debug 定向 5 项通过，0 失败；日志 `/tmp/lutcalc-h07-asset-focused-20260925.log` |
| `swift test -c release --package-path Native/Packages/LUTKit --filter 'UserLUT(ProjectAsset\|Import)ContractsTests'` | Release 定向 5 项通过，0 失败；日志 `/tmp/lutcalc-h07-asset-release-20260925.log` |
| `swift test -c release --package-path Native/Packages/LUTKit --filter 'ProjectContractsTests\|SessionContractsTests'` | 项目 4 项、会话 3 项通过；日志 `/tmp/lutcalc-h07-asset-regression-20260925.log` |
| `swift run -c release --package-path Native/Packages/LUTKit LUTDocumentChecks` | 既有包适配契约通过；日志 `/tmp/lutcalc-h07-asset-document-20260925.log` |

定向测试用真实临时 CUBE 文件、真实 `.lutcalc` 包及 `FileWrapper` 写盘/重开；源文件删除后固定输入 `(0.5, 0.25, 0.75)` 仍得到 `(0.5, 0.5, 2.25)`，重开资源也可进入只读取样会话。测试还覆盖缺少原始字节及字节与会话 LUT 不一致时不能入项目、资源哈希不符拒绝打开、生成请求仍拒绝。追加的不一致契约也先编译失败，日志 `/tmp/lutcalc-h07-asset-binding-red-20260925.log`。此次未运行 macOS/iOS App 的实际系统文稿保存交互，也未做 Files/File Provider 实体设备验证；系统自动保存时机、平台文件协调与多窗口冲突仍待验收。只允许一份项目内用户 LUT，替换/移除及资产编辑历史尚未实现；完整 H07/FULL-05 不勾选。

本段源码 SHA-256：`UserLUTImportSession.swift` 为 `afefc3e7717538e26bb578f95949c970ddea92f9b32f1dc42f88bec60b41ef10`，`LUTProjectDocument.swift` 为 `fe087fde334cbfe75e866734da62ada5b72388db4e3d80e13992213405d0c6ae`，`ProjectDocumentView.swift` 为 `3aee68f60edb086f43aef057a503c832c36b607a21e43e856d8d18d043bb1338`，`ProjectEditingSession.swift` 为 `bed2813c7d419785e665be53a79013e2c8082a8edd1fe9860d49d798dd087c66`，新增测试文件为 `0d06594477bb4bfcb356ae353168995e6f18ff06d5bf34e52736f7f73d2d19da`。本段没有修改数值变换语义、插值规则或生成网格。
