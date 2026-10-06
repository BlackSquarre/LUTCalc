# 原生数值门禁复跑

## 命令

```sh
bash Scripts/verify-native-numerics.sh
```

## 结果

命令退出码为 `0`。本轮通过 `66` 个独立检查，使用 `10` 个 worker；批量生成与读回 `54` 个 CUBE 案例；静态原生边界检查覆盖 `181` 个 Swift 源文件。Double 网格、解析、插值、任务取消与本地提交契约均通过，未发现 WebKit、JavaScriptCore、自有 C/C++ 计算内核或 SwiftPM 内置资源声明。

## 未覆盖范围

该门禁不提供 macOS Finder 直接双击、iPadOS 多窗口、实体 iPhone 11 后台恢复、真实 iCloud/File Provider、目标调色软件往返、完整 ICC/HDR/EDR/OOTF、任意 3D LUT 全局反求、`.labin` 与直接查表替代或公证发布证据。相关范围继续保持未完成，Goal 保持 `active`。
