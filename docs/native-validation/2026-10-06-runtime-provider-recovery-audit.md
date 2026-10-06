# File Provider、目标替换与后台恢复非界面审计

日期：2026-10-06。

## 已由本地 Swift 契约闭合的边界

- `ProjectAssetRecovery` 对书签解析后的文件重新计算 SHA-256；内容被替换时返回 `contentChanged`，不回退到其他候选。
- 书签失效时只在调用方明确提供的授权目录内按 hash 和原文件名重发现；没有授权源时显式返回 `noAuthorizedSource`。
- 新增 `testRevokedBookmarkWithoutReauthorizationFailsClosed`，用无效书签且无授权目录复现授权撤销后的 fail-closed 行为。
- `LocalFileCommit` 已有 `NSFileCoordinator` 协调、默认不覆盖、显式覆盖的原始 inode 指纹检查、同字节替换拒绝和 provider 风格协调错误契约。
- `ExposureBatchCheckpointStore` 已有严格 checkpoint schema、目录/租约身份、跨进程锁、prepared/published/completed 边界及本地 SIGKILL 后独立恢复契约。

## 实际验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ProjectAssetRecoveryContractsTests
```

结果：Release 定向 `6/6` 通过，失败 `0`，退出码 `0`。

## 未覆盖的真实平台证据

本地契约不能证明第三方 File Provider/iCloud 在授权撤销、重新授权、远端冲突、网络离线或协调回调延迟时的系统行为；也不能把本地子进程 SIGKILL 恢复当作 iOS 后台终止恢复。真实 provider 授权失效、跨进程 provider 替换、iPhone 11 后台终止恢复仍需按平台工具取得结果包，不能伪造为通过。

本轮没有改变生产算法、文件格式或 UI；未放宽替换阈值，也未创建全量验收清单。Goal 保持 `active`。
