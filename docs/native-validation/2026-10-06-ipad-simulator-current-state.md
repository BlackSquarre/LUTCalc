# iPad 模拟器当前环境复核

## 命令与结果

```sh
xcrun simctl list devices available
```

Xcode 27.0 的 CoreSimulator 无法初始化设备集，返回 `NSPOSIXErrorDomain Code=12`（无法分配内存），并报告 `Failed to subscribe to notifications from CoreSimulatorService`。本轮没有可用 iPad 模拟器，因此没有执行旋转、多窗口、文稿协调或无障碍 UI 测试，也没有用其他设备替代。

## 结论

这是当前主机的模拟器环境阻塞，不是 iPad 验收通过证据。iPadOS 相关验收继续保持未完成，Goal 保持 `active`。
