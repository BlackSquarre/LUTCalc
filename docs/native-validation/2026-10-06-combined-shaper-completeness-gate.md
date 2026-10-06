# 组合 shaper 完备性门禁验收

## 变更

`CombinedShaperColourInverseReport` 新增 `isGloballyComplete`。只有颜色反求和 shaper 反求都没有未决单元／通道时才返回 `true`；tricubic 候选根仍可返回用于诊断，但不再被误报为全局唯一或多解。

## 实际验证

定向 Release 组合 shaper 契约通过。随后使用低并行原生数值门禁：

```sh
LUTCALC_CPU_COUNT=2 LUTCALC_SWIFT_JOBS=2 \
LUTCALC_TEST_WORKERS=1 LUTCALC_VALIDATION_WORKERS=1 \
LUTCALC_BATCH_WORKERS=1 bash Scripts/verify-native-numerics.sh
```

退出码 `0`。66 项静态、独立参照、格式、项目、任务和 LUTAnalysis 命令行检查通过；日志保存在 `/tmp/lutcalc-numerics-combined-completeness.log`。

## 未覆盖范围

该门禁不证明任意 3D LUT 的连续域全根完备性，不关闭 tricubic 区间根隔离、`.labin`、直接查表、完整 ICC/HDR 或平台发布验收。Goal 继续保持 `active`。
