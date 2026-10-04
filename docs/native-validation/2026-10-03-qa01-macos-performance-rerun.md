# 2026-10-03 QA-01 macOS Double 性能基线复跑

## 范围

本轮在当前工作区重新运行 `LUTPerformanceChecks` Release，测量 D-Log2／D-Gamut2 到线性 ACES AP0 的 17³、33³、65³ `CubeGenerator` 路径。只记录当前主机的标量 CPU 墙钟基线和 Double 位模式校验和，不改变网格、位宽、插值规则、并发策略或数值阈值。

## 工具链与命令

主机：`lingrumbp.local`，arm64 macOS；Xcode 27.0，Apple Swift 6.4。

```sh
swift run -c release --package-path Native/Packages/LUTKit LUTPerformanceChecks
for i in 1 2 3 4 5; do
  swift run -c release --skip-build --package-path Native/Packages/LUTKit LUTPerformanceChecks
done
```

结果包位于 `docs/native-validation/artifacts/2026-10-03-performance-baseline/`。

## 结果

首次完整 Release 运行：

| 网格 | 节点 | 耗时（秒） | 节点/秒 | Double 校验和 |
| ---: | ---: | ---: | ---: | ---: |
| 17³ | 4,913 | 0.001046167 | 4,696,190.95 | `14379552350607772001` |
| 33³ | 35,937 | 0.005349250 | 6,718,138.06 | `1336097751165010835` |
| 65³ | 274,625 | 0.029271292 | 9,382,059.39 | `15217861669287451768` |

随后五次完整 Release 复跑的耗时范围和中位数：

| 网格 | 最小（秒） | 中位数（秒） | 最大（秒） | 中位节点/秒 |
| ---: | ---: | ---: | ---: | ---: |
| 17³ | 0.000369292 | 0.000373292 | 0.000396625 | 13,161,278.57 |
| 33³ | 0.002507375 | 0.002521625 | 0.002661875 | 14,251,524.31 |
| 65³ | 0.018489958 | 0.018510042 | 0.019643292 | 14,836,541.16 |

五次复跑的三个校验和均分别保持为 `14379552350607772001`、`1336097751165010835`、`15217861669287451768`，与既有基线一致。首次运行较慢属于进程和缓存状态差异，不能解释为算法性能提升。

同一完整 Release 运行使用 `/usr/bin/time -l` 记录到最大常驻集 `16,236,544` 字节、peak memory footprint `11,272,720` 字节。这是包含 Swift 运行时和进程启动的上界观测，不是生成内核的隔离峰值，也不构成 iPhone/iPad 预算。

## 当前结论

- 当前 macOS Release 标量路径可复现，Double 位模式没有变化。
- 这不是跨设备性能预算，也没有把单次耗时设为发布门槛。
- 尚未测量峰值内存、批量曝光、用户 cubic／shaper、LUTAnalyst、整图预览、文件写出、取消延迟、实体 iPhone 11 或 iPad 模拟器。
- 本轮 `xcrun devicectl list devices` 显示实体 iPhone 11（`00008030-001015101ABA802E`）当前为 `unavailable`，因此没有用 iPhone Air、镜像或其他设备替代性能证据。
- QA-01、QA-02、QA-03 和发布性能验收继续保持未完成，Goal 保持 active。
- 同步运行 `python3 tools/native-validation/check-release-evidence.py`，按预期退出码 `2`：缺少真实 `docs/native-validation/full-scope-acceptance.json`；没有创建或伪造该清单。

## 日志 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| `lutcalc-performance-release-20261003.log` | `5cbae7a9dd445536e427441bde1dcf4d3988154e8f67e83aac62724431246694` |
| `lutcalc-performance-full-repeat-20261003.log` | `84e94ccc18d500fb72e6d143d4ac0e2dd74c9b10c9b1b8cc3b0bba1bfa26edc3` |
| `lutcalc-performance-quick-repeat-20261003.log` | `5a20528e9c94a98e2904394c4847e61fd107e3c226b4134a5bb44f98b4f9da83` |
| `lutcalc-performance-rss-20261003.log` | `91fd41a05722b8d5da5a6cdd4e528df3a4a07b38983378189e04baa11b509d93` |
| `release-evidence-check-20261003.log` | `6f53f51342a12077a132f6a477330eeeb0aaac7ab614c30e15363209cff1e86e` |
| `devicectl-list-devices-20261003.log` | `7fae4154eee5680850426de46a5bd2e495041563b334d725bbb4dddadf0365dd` |
