# 原生公式契约批量调度阶段验收

日期：2026-09-25。范围：把已有的独立曲线/伽马命令行契约从串行调用改为有界批量调度，验证参数和公式结果保持不变。

## 实施

- 新增 `tools/native-validation/run-check-batch.py`，用显式清单调度 6 个既有检查产品：Rec.709、S-Log3、LogC4、V-Log、Apple Log/Log 2 和 Rec.2100 HLG。
- 默认使用 2 个 worker，允许通过 `LUTCALC_BATCH_WORKERS` 设为 1–4；产品、夹具、key 和 worker 数量在启动阶段检查。
- 每个检查仍由原 Swift 可执行文件加载原有独立夹具、执行原有 Double 标量/全码/矩阵/计划比较；批量脚本只负责并发进程和按清单顺序输出，不改参数、精度、阈值、节点或算法。
- `verify-native-subset.sh` 已接入该批量入口。既有 33³/65³ CUBE 生成与独立读回继续由 `run-cube-batch.py` 负责，两者职责分开。

## 契约先行

新增 `tests/native_validation_batch_test.py`，先固定以下边界后实现：

- 6 个检查产品各出现一次且顺序稳定；
- Rec.709/S-Log3 夹具参数完整，HLG 不伪造夹具；
- worker 不在 1–4 时在执行前退出；
- 缺少产品时在批次启动前拒绝。

定向结果：4 项 Python 契约通过。

## 验证结果

- Release 包构建：`swift build -c release --package-path Native/Packages/LUTKit` 通过。
- 直接批量运行：6 个独立检查、2 个受控 worker 全部通过，耗时约 0.10 秒；六个产品的原始输出与逐个串行运行结果逐行完全一致，批量输出顺序稳定；S-Log3/LogC4/V-Log/Apple Log 的既有尺度化门槛仍为 `2e-12`，HLG 33³/65³ 全节点均通过。
- 原生子集回归：`bash tools/native-validation/verify-native-subset.sh` 退出码 0；其中当前 CUBE 清单为 36 个生成/读回对。日志：`/tmp/lutcalc-batch-formula-subset.log`，SHA-256：`5a0c49a67bb84de20c4c7c035c1e0f771e792c1d0e916f4b0a7e739167b74692`。

本阶段只改变验证调度，不把批量结果称为完整迁移、真机验收或发布通过；真机和发布清单继续按路线图状态处理。
