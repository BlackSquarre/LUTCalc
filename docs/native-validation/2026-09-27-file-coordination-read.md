# 2026-09-27 File Provider 读取协调契约阶段

## 实现

- `NativeUserLUTLoader` 在 security-scoped URL 生命周期内通过 `NSFileCoordinator` 读取用户主动导入的 LUT；读取器以协议注入，解析仍在后台任务中使用 `Double` 数据路径。
- 协调器读取逐块检查取消和 `ProjectAssets.maxAssetBytes`，协调失败不会转换成空数据或成功结果。
- 该改动只影响用户导入 LUT 的读取边界，不把内置变换改成资源读取，也不涉及项目包写入或生成算法。

## 先行契约与结果

定向命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter SecurityScopedLoaderContractsTests
```

结果：`SecurityScopedLoaderContractsTests` 7 项通过、0 失败。新增两项分别验证：

1. 成功读取确实调用协调器，并在同一 URL 上成对 start/stop security scope。
2. 协调器失败原样返回，仍成对释放 security scope。

另有真实本地文件测试：`testNativeCoordinatorReadsLocalFileWithoutChangingBytes` 创建临时 `.cube`，经过实际 `NSFileCoordinator` 读取后逐字节相等；`SecurityScopedLoaderContractsTests` 共 8 项通过、0 失败。日志 `/tmp/lutcalc-coordinator-real-read-20260927.log`。

## 全包与构建回归

- `swift test --package-path Native/Packages/LUTKit -c release`：退出码 `0`；日志 `/tmp/lutcalc-coordinated-full-swift-20260927.log`，SHA-256 `a77bbfb83c1d9bb20ae759be584b568bbe3f836e1c9dc881cd7cf61e5b0d6cfe`。
- macOS Release 构建：退出码 `0`；日志 SHA-256 `612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`。
- iOS Simulator Release 构建：退出码 `0`；日志为空，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- iOS generic Release 构建：退出码 `0`；日志为空，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

## 未覆盖

本阶段没有取得 iCloud/File Provider 授权撤销、外部替换竞争、离线恢复、磁盘故障或真实第三方 Provider 的平台证据；这些仍需保留在 H08、FLOW-02/04、QA-02 和最终发布清单中。
