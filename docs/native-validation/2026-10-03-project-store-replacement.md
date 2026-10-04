# 项目包目标替换竞争与协调提交非 UI 阶段验收

日期：2026-10-03

## 范围

本轮处理 H08/H12/FULL-08 的项目存储发布边界。`ProjectStore.saveExisting` 现在使用 `NSFileCoordinator` 协调目标项目包，在协调回调内再次读取 manifest，并比较项目目录的设备号、inode 与 manifest SHA-256。目标在发布边界被其他写入者替换时返回 `.concurrentModification`，不覆盖竞争者的项目包。

这条路径与 LUT 文件导出的本地提交保护分开实现，仍保持项目包自包含资源、staging/backup 恢复和既有 expected manifest 检查语义。

## 契约与实现

先添加 `ProjectStoreReplacementContractsTests`，红灯阶段因测试专用协调保存入口尚不存在而失败。实现后覆盖：

- 目标在协调发布边界被另一个项目替换时拒绝提交，并保留竞争者字节；
- 竞争者与原项目 manifest 字节相同但目录身份不同，仍拒绝提交；
- 竞争者包不会被清理，临时项目 staging 不会泄漏。

## 实际验证

工具链：Xcode 27、Swift 6（swift-driver 1.168.6）、macOS 27 SDK、Apple Silicon arm64。命令、日志、源码哈希和构建结果见 [artifact 目录](artifacts/2026-10-03-project-store-replacement/)。

结果：

- Debug 定向 2 项、Release 定向 2 项，0 失败；
- Release 全量 8 个测试包共执行 602 项，0 失败；LUTFormats 的 `.labin` 与 NCP 外部夹具各 1 项按设计跳过；
- macOS、iOS generic、iOS Simulator generic Release 构建退出码均为 0；
- 源码审计通过，146 个 Swift 源文件无所列禁止运行时或内置查找资产；
- 三个 App 包审计通过，无所列 LUT/脚本文件且未直接链接 WebKit/JavaScriptCore；
- 构建期间仍有当前主机 CoreSimulator 服务初始化警告，但 generic simulator 构建成功；这不是 iPad 交互验收证据。

日志 SHA-256：

```text
契约红灯       298c5c905da1a15852314f523a707b519e7c161cc3498204808ac5dcbd57e3f0
Debug 定向      5d18710c4d9320b144df70e575e341f98b9e34b12b57c62eeeff454353f1d738
Release 定向    3945802e3146cc35b7759e318840c56906b486ae9c9f8db8881addeb9abb94a0
Release 全量    d839fdee07ecafe232d9d20a94d6da3bcee5628b6e2484a847ea19ecb56a213e
macOS 构建      14e3ccb5d773be20fde7dc5d0b2be3bb4bd11ad7612106775a08098e4fd77f17
iOS 构建        43e04edf8cfd14ee305ef2f3bb32f82df44ce7c4b438c6e741233610bf6ba7be
模拟器构建      dbdd62370dbae4376e12e1c7f6703c7a921dfd94aac65f7fb20adff6d352eda2
源码审计        d3be41b866152b5840b67fbe667a6371e677fa390a20ee58f96d4f1c07fe63e2
App 包审计      5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f
```

## 未覆盖范围

本轮证明的是本地 Foundation 协调回调和目录身份检查，不证明真实 iCloud/File Provider 的 provider 事务、跨进程不合作写入者、授权撤销、stale bookmark 续期、网络离线、磁盘故障或 iPhone 11 后台恢复。真实 Files/Finder 交互、iPad 多窗口和其他 UI 按要求暂缓。

完整 ICC、HDR/EDR/OOTF、LUTAnalyst、全部格式与目标调色软件互操作、性能预算、签名发布和 `docs/native-validation/full-scope-acceptance.json` 仍未完成；Goal 保持 active。

