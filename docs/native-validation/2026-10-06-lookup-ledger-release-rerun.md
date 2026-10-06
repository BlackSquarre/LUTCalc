# 查表台账 Release 复跑

## 命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'LookupResourceInventoryContractsTests|RegistryContractsTests|SL3LookupGapContractsTests|CanonLookupGapContractsTests|NikonLookupBlockContractsTests'
```

退出码 `0`。LUTCatalog 执行 `34` 项，失败 `0`；Canon、Nikon、SL3 阻塞契约和资源清单对账均通过。日志 SHA-256：
`97c65ea8aeebcbbf7d6df17f7c8d756094a7be12a689953f5545cd62f68a71cd`。

## 台账状态

旧 JavaScript 直接查表注册与 Swift 阻塞白名单保持一致，仍为 `0/45` 替代；根目录 `.labin` 资源与冻结清单保持一致，仍为 `0/9` 替代。没有复制 LUT、样条或旧资源，也没有新增猜测性算法身份。

## 未完成范围

取得厂商连续定义、适用范围、非灰轴语义和独立网格参照前，不关闭这些条目。完整 ICC/HDR/OOTF、任意 3D 反求、第三方软件往返和发布验收仍未完成，Goal 保持 `active`。
