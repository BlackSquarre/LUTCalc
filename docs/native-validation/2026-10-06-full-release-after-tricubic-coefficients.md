# tricubic 系数接口后的全量 Release 回归

## 命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`。完整 LUTKit Release 回归通过；LUTAnalysis 执行 `93` 项、失败 `0`，其余测试包也全部通过。日志 SHA-256：
`3efe6ccb7bf6137923909c5ba621de7525d6cf5548b3fae2aa215bb3e1aaa95a`。

本回归验证新增 tricubic Bernstein 系数接口和 `cellOutputBounds` 复用没有破坏既有解析、数值、项目、ICC、任务调度和反求契约。

这仍不代表 tricubic 全局全根证明、`.labin`/直接查表替代、完整 ICC/HDR/OOTF、平台真机或发布验收完成。Goal 保持 `active`。
