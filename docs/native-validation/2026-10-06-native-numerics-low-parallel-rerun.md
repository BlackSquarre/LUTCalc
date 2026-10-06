# 2026-10-06 原生数值门禁低并行复验

默认并行度运行 `Scripts/verify-native-numerics.sh` 时，Swift 子进程收到系统 `SIGKILL (137)`，不是契约失败；日志在 H12 阶段前均正常。为排除资源压力，使用低并行度重跑：

```sh
LUTCALC_CPU_COUNT=2 LUTCALC_SWIFT_JOBS=2 LUTCALC_TEST_WORKERS=1 \
LUTCALC_VALIDATION_WORKERS=1 LUTCALC_BATCH_WORKERS=1 \
bash Scripts/verify-native-numerics.sh
```

低并行复验退出码 0，静态边界、独立参照、格式、H08-H12、H10 根求解和原生子集门禁全部通过。该门禁仍不等价于双端 App、真机、完整 ICC/HDR 或发布清单完成。
