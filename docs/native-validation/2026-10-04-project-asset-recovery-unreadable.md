# 项目资产恢复 bookmark 不可读边界验收

## 范围

本工作包只处理本地项目外部资产恢复中一个明确的失败语义：安全 bookmark 已成功解析到原文件，但读取该文件内容时发生权限或 I/O 错误。此时不能把另一授权目录里同 SHA-256 的文件当成原 bookmark 的替代品。本记录不声称覆盖真实 iCloud、File Provider、撤权通知或后台恢复。

## 契约先行

新增 `testResolvedBookmarkUnreadableDoesNotFallBackToAnotherAuthorizedFile`，先用未增加错误枚举的旧实现编译，因缺少 `bookmarkSourceUnreadable` 退出码为 `1`；红灯日志保存在 `artifacts/2026-10-04-project-asset-recovery/recovery-unreadable-red.log`。

夹具创建原始文件和另一授权根中的同字节文件，生成原始文件 bookmark 后将原始文件权限设为 `000`。期望结果是显式 `ProjectAssetRecoveryError.bookmarkSourceUnreadable`，而不是从另一授权根重发现。测试清理阶段恢复权限后删除临时目录。

## 实现与验证

`ProjectAssetRecovery.resolve` 在 bookmark 已解析且 SHA-256 读取失败时直接返回 `bookmarkSourceUnreadable`；只有 bookmark 无法解析时，才允许调用方显式提供的授权根进行 hash 重发现。bookmark 读取到不同内容时原有 `contentChanged` 拒绝保持不变。

实际命令和日志位于 `artifacts/2026-10-04-project-asset-recovery/`：

- Debug 定向：5 项通过，0 失败；
- Release 定向：5 项通过，0 失败；
- Swift Release 全量：8 个测试包共 681 项，0 失败；LUTFormats 的既有外部夹具跳过 2 项；
- macOS Release generic 构建：退出码 0；
- iOS Release generic 签名构建：退出码 0；
- 153 个 Swift 源文件静态审计通过；
- macOS/iOS 实际 App 包审计通过；
- 发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2，未创建或伪造该清单。

## 未覆盖范围

仍未证明真实 provider 撤权、bookmark stale 续期失败、跨进程 provider 目标替换、祖先目录身份保护、哈希读取到最终替换之间的非协作窗口、磁盘故障矩阵和 iPhone 11 后台终止恢复。UI 继续按用户要求暂缓；H/FULL 和 Goal 保持 active。
