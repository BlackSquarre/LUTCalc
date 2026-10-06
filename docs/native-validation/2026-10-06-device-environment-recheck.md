# 设备环境只读复验

## 实际命令

```sh
xcrun devicectl list devices
xcrun simctl list devices available
git diff --check
```

## 结果

- 实体 iPhone 11 `00008030-001015101ABA802E` 当前显示 `connected`，型号为 `iPhone 11 (iPhone12,1)`；没有把 iPhone Air 或其他设备作为替代证据。
- `xcrun simctl list devices available` 当前因 CoreSimulator 无法初始化设备集而失败，底层为 `NSPOSIXErrorDomain Code=12`（无法分配内存）。因此本轮没有声称新增 iPadOS 模拟器交互验收，也没有创建或删除模拟器设备。
- `git diff --check` 通过。

该记录仅说明当前外部设备条件，不等同于 iPhone 11 新的 Files/UI 通过证据，也不关闭 iPad 多窗口、旋转、文稿协调、无障碍、File Provider 或完整发布范围。
