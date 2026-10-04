# KineLOG3 接线后的批量回归与发布门槛记录

日期：2026-09-25

## 执行结果

在加入 KineLOG3/Kinefinity Wide Gamut 官方同色域子集后，先执行批量入口：

```text
bash tools/native-validation/verify-native-subset.sh
```

批量日志：`/tmp/lutcalc-kinelog3-subset-20260925-run2.log`；SHA-256：`4191b960d323834e14ee00f9c42afc2495c5ad52341ecae0746754651ae836c6`。

- 静态原生边界、旧 Node 契约、格式/项目/预览/任务契约均通过。
- 注册表契约通过：18 条曲线、12 个色域、18 个预设。
- L-Log 和 KineLOG3 的 33³/65³ 独立逐节点检查均通过；KineLOG3 最大尺度化误差 `1.1150635581761299e-15`，门槛 `2e-12`。
- 没有改变 Double、网格尺寸、轴序或冻结阈值。

随后执行完整入口：

```text
bash tools/native-validation/verify-native-release.sh
```

完整日志：`/tmp/lutcalc-kinelog3-release-20260925.log`；SHA-256：`6e0c4621deb39915ebd9fa56def42fdb837555187b598c399bba65f585823383`。

- Swift Release 全部测试目标通过；`swift test --list-tests` 当前列出 **145 项**，0 失败。
- macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`。
- 三个实际 App 包资源审计通过：未发现列明的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

## 发布门槛

入口退出码为 **2**，唯一直接失败项仍是：

```text
发布证据检查未通过：缺少全量发布验收清单 docs/native-validation/full-scope-acceptance.json
```

没有创建或补造该清单，也没有把子集或阶段回归结果标为发布就绪。

## 状态边界

KineLOG3 当前只证明官方同色域标量公式、Kinefinity Wide Gamut 身份、批量 CUBE 读回和三平台构建；跨色域矩阵、设备全范围、真机新增曲线、Files 独立读回/取消、目标软件导入、完整 H01–H14 和真实全量发布验收仍未完成。
