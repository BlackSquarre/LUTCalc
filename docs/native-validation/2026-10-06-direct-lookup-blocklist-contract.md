# 直接查表注册阻塞白名单契约验收

## 范围

本包只把既有查表替代台账中的 45 个注册名称冻结为原生目录审计白名单。它不保存 LUT 数值、旧 JavaScript 数组、`.labin`、样条控制点或任何等价采样表，也不新增变换算法。

契约要求每个名称在 `AlgorithmCatalog` 中都不能解析为 transfer、色域或预设。这样后续目录扩展若误把资料不足的查表项登记为 Swift 算法，会先在测试中失败；用户主动导入 LUT 的解析路径不受影响。

## 契约先行

先在 `RegistryContractsTests` 增加 `testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity`，但尚未提供白名单 API。首次 Release 编译按预期失败，错误为 `AlgorithmCatalog` 缺少 `blockedLookupRegistrationNames`。

## 实现与验证

实现仅在 `AlgorithmCatalog` 增加公开的 45 名只读白名单，并逐项断言 `transfer(named:)`、`colorSpace(named:)`、`preset(named:)` 均为 `nil`。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter RegistryContractsTests/testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity
```

结果：Debug 与 Release 各执行 1 项、0 失败、退出码 0。Release 日志为 `/tmp/lutcalc-blocked-lookup-release.log`，Debug 日志为 `/tmp/lutcalc-blocked-lookup-debug.log`。工具链为 Xcode 27 / Swift 6，目标为 macOS arm64。

## 未覆盖范围

该契约只防止 45 个查表名称被误注册，不证明这些项目已有连续公式，也不减少直接查表替代计数；台账仍为 `0/45`。9 个 `.labin` 资源仍为 `0/9`。DJI DLog-M、Sony/ARRI/Canon/RED/Panasonic 查表变换仍需公开连续定义、适用范围和独立参照后另行实现。完整 LUTAnalyst 重建、任意 3D 全局反求、ICC/HDR、格式往返、平台和发布验收均不在本包内。

Goal 保持 `active`。
