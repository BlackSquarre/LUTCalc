# 原生曲线批量生成与独立读回阶段验收

日期：2026-09-25。范围：把既有 33³/65³ 曲线 CUBE 生成和独立读回从串行 shell 循环改为受控批次；不改变算法、预期值、Double 精度或误差门槛。

## 原有流程

一次 Release 构建后，验证入口逐个启动 `LUTReferenceCLI` 生成临时 CUBE，再逐个启动对应 Python 独立读回器。每个曲线和网格独立验证，结果可靠，但进程启动和 65³ 计算主要串行。

## 批量流程

新增 `tools/native-validation/run-cube-batch.py`，由显式清单维护 20 个曲线/色域案例、每案 33³ 和 65³ 两个网格，共 40 个生成/读回对：

1. 先以默认 2 个受控 worker 并行生成全部临时 CUBE；
2. 生成阶段全部成功后，再以同样的有界并发并行运行原有独立读回器；
3. 每个案例仍使用原来的 preset、fixture、解析器、节点顺序和 `scaledError <= 2e-12` 门槛；
4. 输出目录使用临时目录，读回完成后自动清理；任一案例失败会带案例名和原始命令退出，不会把部分批次报告为通过。

清单自身有重复 key、非法网格和缺少 CLI 的失败检查；`LUTCALC_BATCH_WORKERS` 可在不改结果的情况下把 worker 限制在 1–4。

定向失败契约已验证：`--workers 0` 和缺少 `LUTReferenceCLI` 均在生成前拒绝，退出码分别为 2；`bash -n tools/native-validation/verify-native-subset.sh` 通过。

## 结果

定向批量命令：

```text
python3 tools/native-validation/run-cube-batch.py Native/Packages/LUTKit/.build/release/LUTReferenceCLI --workers 2
```

历史 32 个生成/读回对全部通过；本轮加入 ProPhoto 与 BBC 批次后，40 个生成/读回对全部通过。ProPhoto 33³/65³ 最大尺度化误差为 `2.220446049250313e-16`，BBC 0.4 预设 33³/65³ 最大尺度化误差为 `0`，均低于 `2e-12`。本轮子集日志为 `/tmp/lutcalc-prophoto-bbc-batched-subset-20260925-rerun.log`，SHA-256：`f1d14d5d0c8f5b2113b39d2449f74948a4617471ea3b7e2b091cb732bdc19015`。

批处理接入后的完整 Release 回归日志为 `/tmp/lutcalc-h12-format-batched-release-20260925.log`，SHA-256：`46976acf9bf2d9a9c5c9bf1502e74d244a53387a8856428a48dd4af737104f5f`：157 项 Swift XCTest、三个 Release 构建和三包资源审计通过；发布入口仍因缺少真实全量验收清单退出码 2。

这项优化只改变调度方式，不把批次结果当成完整迁移、真机验收或发布通过。真机连接不稳的新增测试仍按用户要求暂缓集中执行。

本轮同步加入 `LUTReferenceCLI` 的 `prophoto-exposure`/`bbc-exposure` 入口、独立解析式读回器 `verify-prophoto-bbc-cube.py`，并把批量清单契约从 18 项更新为 20 项；`python3 -m unittest tests/native_batch_manifest_test.py` 通过。Swift Release 全量回归清单为 205 项，日志 `/tmp/lutcalc-prophoto-bbc-full-swift-20260925.log`，SHA-256：`f05fc8ed8b177f9b9091f16528792fe09183c9c13f432c08ed798622a9ee5f0b`。
