# Leica L-Log 接线后的批量回归与发布门槛记录

日期：2026-09-25

## 执行结果

在加入 L-Log BT.2020 子集并修正独立读回参考方向后，执行：

```text
bash tools/native-validation/verify-native-release.sh
```

完整日志：`/tmp/lutcalc-llog-release-20260925.log`；SHA-256：`41fa9c8da8a097127a39f404ff8953263fd1299ac6b2800d0021c112e075acac`。

- 静态原生边界检查通过：76 个 Swift 源文件；没有发现列明的脚本运行时、内置 LUT、旧 `.labin` 或 Package resources 声明。
- 旧 Node 契约 11 项通过。
- Python App 包审计契约 3 项通过。
- Swift Release 全部测试目标通过；`swift test --list-tests` 当前列出 141 项，0 失败。
- macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`。
- 三个实际 App 包资源审计通过：未发现列明的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。
- 批量原生子集入口中的 L-Log 33³/65³ 独立逐节点检查通过；最大尺度化误差均为 `3.049417739399331e-16`，门槛 `2e-12`。

## 发布门槛

入口最终退出码为 **2**。唯一直接失败项是：

```text
发布证据检查未通过：缺少全量发布验收清单 docs/native-validation/full-scope-acceptance.json
```

没有创建或补造该清单，也没有把本批次子集结果标为发布就绪。

## 批量策略

本轮一次 Release 构建后复用同一产品目录，顺序执行旧行为、格式、曲线来源、33³/65³ CUBE、项目、预览和任务契约。新增曲线仍保留定向契约用于快速定位，再进入集中回归；各曲线独立脚本继续输出最大、RMS、P99 和固定门槛，避免只看总测试数。

## 状态边界

代码、构建、数值状态已分别通过本记录所列子集；真机新增 L-Log 数值、Files 独立读回/取消、目标软件导入、完整 H01–H14 和真实全量发布验收仍未完成。真机连接不稳定的剩余项目按用户要求留到最后集中执行。
