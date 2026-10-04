# H12 旧设置曲线/色域候选后的批量回归与发布门槛记录

日期：2026-09-25

## 执行结果

H12 旧设置检查器新增严格注册曲线/色域名称候选后，执行批量入口：

```text
bash tools/native-validation/verify-native-release.sh
```

完整日志：`/tmp/lutcalc-h12-legacy-gamma-release-20260925.log`；SHA-256：`bf8af332e66d469e273d70d7826fccb4e0ff34e2b6c0e55a1c9aa462b0c8dcc6`。

- Swift Release XCTest 共 **147 项**，0 失败。
- 旧 Node 契约、Python 独立参照与原生边界检查通过。
- macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`。
- 三个实际 App 包资源审计通过：未发现列明的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。
- 批量 33³/65³ CUBE 生成和逐节点读回继续复用同一次 Release 产品目录；新增及既有曲线结果均低于冻结门槛 `2e-12`。

## 发布门槛

入口退出码为 **2**，唯一直接失败项仍是：

```text
发布证据检查未通过：缺少全量发布验收清单 docs/native-validation/full-scope-acceptance.json
```

没有创建或补造该清单，也没有把本阶段回归标为完整迁移或发布就绪。

## 状态边界

本记录只覆盖 H12 只读候选接线后的代码、数值、构建和资源审计。旧设置仍不创建 `ProjectManifest`，`canMigrate` 仍为 `false`；真机新增曲线、Files 独立读回/取消、第三方导入、完整 H01–H14 与真实全量发布验收仍未完成。
