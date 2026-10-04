# CUBE 预设批量清单补齐阶段验收

日期：2026-09-25。范围：补齐既有批量 CUBE 清单遗漏的两条 DJI 研发预设，不改变算法、参数、输出尺寸、Double 生成路径或冻结门槛。

## 契约先行与实现

新增 `tests/native_batch_manifest_test.py`，要求批量清单覆盖当前 18 条可由独立 CUBE 读回器验证的预设。首次运行显示实际只有 16 条，随后在 `run-cube-batch.py` 加入 `dlog2-linear-ap0` 与 `dlog2-srgb-w3c`，复用既有 `verify-first-chain-cube.py` 与 `verify-srgb-cube.py` 独立读回。前者兼容批量入口的 `--size` 参数，同时保留原 `--expected-size` 参数。Rec.2100 HLG 仍由独立 `LUTHLGChecks` 的 33³/65³ 全节点契约覆盖，不伪装为已有 CUBE 读回案例。

## 验证结果

- 清单契约先失败（16 对预期 18），实现后通过。
- 18 条预设 × 33³/65³ 共 36 个 CUBE 生成与独立读回对全部通过，2 个受控 worker。
- DJI D-Log2→线性 AP0 最大尺度化误差：33³ 与 65³ 均为 `3.064215547965432e-14`；DJI D-Log2→sRGB W3C：33³ 为 `2.9476421303797906e-14`，65³ 为 `2.739475313262574e-13`；均低于冻结门槛 `2e-12`。
- 合并公式契约批量调度后，原生子集全部通过，日志 `/tmp/lutcalc-batched-current-subset.log`，SHA-256 `c1c29026f571ffd5159a6d368290f81ddc4b5a257a4105a5ebd1f73df3d7c708`。
- 两项批量入口的 5 个 Python 契约已接入原生子集脚本。最终完整 Release 入口中，Swift XCTest 8 个测试目标合计 179 项、0 失败；macOS、iOS Simulator、iOS generic 三个平台构建成功，3 个 App 包资源审计通过。日志 `/tmp/lutcalc-batched-current-release-final.log`，SHA-256 `19ffa74b7966fab811bec09b7e7aabf5261f268a5a78efdfba432a7eb8f9b0e4`。
- 完整入口最终退出码 2，直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。未创建或伪造该清单。

本项仅补齐已有参数批次与独立数值读回。iPhone Air 真机 SPI3D 容器取回与逐节点比较已有单项证据；剩余真机 Files 独立读回、取消、iPadOS 交互及完整 H01–H14/发布验收继续保持未完成。
