# 2026-10-04 实体 iPhone 11 后端性能探针验收

## 范围

本轮只测量原生 Swift 后端在实体 iPhone 11 上生成 17³、33³、65³ Double LUT 的耗时、节点数和 Double 位模式校验和。探针不改变 `TransformPlan`、`CubeGenerator`、网格、位宽、插值规则或数值阈值；校验和只用于结果稳定性检查，不是独立数值参照。没有执行 UI 自动化，也没有把本轮结果解释为完整性能预算或发布验收。

## 契约与实现

- 先运行 `swift test --package-path Native/Packages/LUTKit --filter DevicePerformanceProbeContractsTests`，3 项通过。
- 新增 `DevicePerformanceProbe`，schema 为 `native.device-performance.v1`，固定使用 `minimal-dlog2-v1` 计划和 `Double` 位模式校验和。
- iOS 验收入口支持 `LUTCALC_DEVICE_PERFORMANCE_PROBE=1`。探针放在 utility 队列执行；主机字段固定为 `Apple-platform-runtime`，避免 iOS 启动时反向 DNS 阻塞。

## 实际环境与命令

- Xcode 27.0（27A266a）、Swift 6.4、iOS SDK 27.0、`devicectl` 642.16。
- 设备为实体 iPhone 11，UDID `00008030-001015101ABA802E`，iOS 27.0（24A437）。
- Release 构建退出码 `0`，结果包中的 `signed-build-v3.log` 记录完整命令和工具链。
- 安装退出码 `0`。使用环境变量启动：

  ```sh
  xcrun devicectl device process launch \
    --device 00008030-001015101ABA802E --terminate-existing --no-activate \
    --environment-variables '{"LUTCALC_DEVICE_PERFORMANCE_PROBE":"1"}' \
    org.lutcalc.native.dev.ios
  ```

- 启动退出码 `0`；等待 8 秒后用 `device info files` 发现结果，再用 `device copy from` 取回。

## 实测结果

| 网格 | 节点数 | 秒 | 节点/秒 | 校验和 |
|---:|---:|---:|---:|---:|
| 17³ | 4,913 | 0.003047333 | 1,612,229 | 14379552350607772001 |
| 33³ | 35,937 | 0.013244083 | 2,713,439 | 1336097751165010835 |
| 65³ | 274,625 | 0.130624291 | 2,102,404 | 15217861669287451768 |

节点数与 `size³` 一致，JSON schema、计划版本和三组校验和均可解析复核。原始结果为 [lutcalc-device-performance-v3.json](artifacts/2026-10-04-device-performance-probe/lutcalc-device-performance-v3.json)，命令及设备结果在 [结果包](artifacts/2026-10-04-device-performance-probe/) 中。

## 未覆盖与限制

- 这是单台 iPhone 11、单次启动、单一最小计划的后端探针，不能替代重复测量、热稳态、内存峰值、取消延迟、后台恢复或完整性能预算。
- 没有独立参照证明计算准确度提升；本轮只验证节点计数、耗时和 Double 位模式稳定性。
- 先前不带分隔符的启动命令失败，以及启动主线程读取 `ProcessInfo.hostName` 触发 20 秒看门狗的 `.ips` 日志均保留，未伪装成通过。

