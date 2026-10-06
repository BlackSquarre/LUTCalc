# 当前目录计数复核

## 命令与结果

```sh
swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
```

退出码 `0`。当前注册表基础契约报告 `82` 个曲线、`23` 个色域、`76` 个预设，并通过稳定 ID、别名、来源、重复引用和悬空引用检查。日志 SHA-256：
`299d3cb6ed9f838ebb2b3ab6c1a1bbc7cd7e00e3648ef0c6ee676a2718e927d9`。

## 范围

该命令只验证目录结构和已有算法身份可达性，不证明每个身份都有独立厂商模型、真实设备范围或第三方逐码参照；`.labin` `0/9`、直接查表 `0/45`、完整 ICC/HDR/OOTF、LUTAnalyst 全局反求和平台发布仍未完成。Goal 保持 `active`。
