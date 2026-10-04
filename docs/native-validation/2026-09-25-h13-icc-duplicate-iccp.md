# H13 PNG 重复 iCCP 阶段验收

日期：2026-09-25

## 范围

PNG 只允许一个 `iCCP` chunk。源 ICC 读取器此前在遇到第一个 `iCCP` 后立即返回，后续重复 chunk 不会被检查。本阶段只收紧来源 profile 的结构边界，不执行 ICC 颜色转换，也不改变 ImageIO 的显示空间行为。

## 契约先行

在 `LUTImageChecks` 中把真实嵌入 ICC PNG 的 `iCCP` chunk 复制一份插入 `IEND` 前，先验证重复 profile 会被拒绝。旧实现按预期报告 `duplicate iCCP accepted`。

## 实现

- `SourceICCReader` 记录是否已经见过 `iCCP`；第二个 `iCCP` 返回 `invalidPNG`。
- 首个 `iCCP` 解压并完成 ICC 固定头、tag directory 与 payload 摘要校验后暂存，继续扫描剩余 PNG chunks，再返回该 profile。这样重复 chunk 能被发现。

## 验证

命令：

```text
bash tools/native-validation/verify-native-subset.sh
```

结果：静态边界、旧 Node/Python 契约、32 个批量 CUBE 生成/读回案例、H12 项目契约、H13 图像夹具与重复 `iCCP` 拒绝均通过，入口退出码 0。定向失败日志：`/tmp/lutcalc-h13-duplicate-iccp-red-20260925.log`；通过日志：`/tmp/lutcalc-h13-duplicate-iccp-green2-20260925.log`。

随后完整执行 `bash tools/native-validation/verify-native-release.sh`：165 项 Swift Release XCTest、旧 Node/Python 契约、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过。日志为 `/tmp/lutcalc-h13-duplicate-iccp-release-20260925.log`，SHA-256 为 `9fe80a68a4804661b419b256744b4f7e13abc17ba670a3a65c5796a7ebab0ee2`；发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2。

## 未完成项

其他 PNG chunk 的完整 CRC 审计、完整 ICC tag 类型、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 读回/取消仍未完成。
