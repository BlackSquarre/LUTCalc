# 原生验证标准入口阶段验收

日期：2026-09-27。

## 变更

新增三个仓库标准入口：

- `Scripts/verify-native-fast.sh`：Swift Release 测试与既有 Node 测试。
- `Scripts/verify-native-numerics.sh`：调用冻结的原生子集数值、格式、项目、预览、任务和分析契约。
- `Scripts/verify-native-release.sh`：调用完整发布入口，继续要求真实的全量验收清单。

三个脚本均从脚本自身位置解析工程根目录，不依赖当前工作目录；没有改变网格尺寸、位宽、插值方式或精度门槛。

## 实际验证

```text
bash -n Scripts/verify-native-fast.sh Scripts/verify-native-numerics.sh Scripts/verify-native-release.sh
Scripts/verify-native-fast.sh
```

结果：脚本语法检查通过；快速入口退出码 `0`，Swift Release 测试和 Node 测试均通过。日志 `/tmp/lutcalc-verify-native-fast.log`，SHA-256：`7f0f9a3ef82e0812e1d661683efbd70f6d689f7154fb171cd92f16d0ce7f3cfc`。

随后实际运行 `Scripts/verify-native-numerics.sh`，退出码 `0`；原生子集静态边界、公式、格式、项目、预览、任务和分析契约全部通过。日志 `/tmp/lutcalc-verify-native-numerics.log`，SHA-256：`877a1584d3a3e7cb1dc587da7ab5e66424e24f38ce1af4e47377eda68824f940`。

完整发布入口仍由 `tools/native-validation/check-release-evidence.py` 检查真实 `docs/native-validation/full-scope-acceptance.json`；清单缺失时必须退出 `2`，本阶段没有创建或绕过该清单。

## 未覆盖

本阶段只补齐验证命令入口，不扩大功能覆盖，也不改变 H01–H14、FULL-01–FULL-08、平台真机或发布状态。
