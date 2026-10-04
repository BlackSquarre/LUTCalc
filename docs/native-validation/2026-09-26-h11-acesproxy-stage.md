# H11 ACESproxy 10/12-bit 阶段验收

日期：2026-09-26  
范围：ACESproxy 10-bit 与 12-bit 的解析式 transfer、目录注册、同 AP1 曝光计划、CUBE 生成与独立 Decimal 读回。

## 实现

- 新增 `Native/Packages/LUTKit/Sources/LUTCore/ACESProxyTransfer.swift`，只使用 `Double` 和 `log2`/`exp2`，没有 LUT、采样数组或压缩数据。
- 10-bit 参数：`black=64`、`max=1023`、`multiplier=50`、`offset=425`。
- 12-bit 参数：`black=256`、`max=4095`、`multiplier=200`、`offset=1700`。
- 低线性分支为 `2^-9.72 / 0.9`；低于或等于该阈值的编码结果为合法黑码。由于存在 legal-range black pedestal，数据域输入 0 不要求恒等往返；黑码行为由专门契约覆盖。
- 接入 `TransferID`、`TransformPlan`、`AlgorithmCatalog`、`LUTReferenceCLI` 和批量清单。预设为 `acesproxy10-exposure`、`acesproxy12-exposure`，均为 ACES AP1 同空间计划。

公开来源：<https://docs.acescentral.com/encodings/acesproxy/>。独立读回脚本为 `tools/native-validation/verify-acesproxy-cube.py`，使用 80 位 Decimal 重算公开公式。

源码 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `ACESProxyTransfer.swift` | `f873f55fcbc0b3ac3a9bf10003b4aa214c0027aae76a24fb0faac44810c82e23` |
| `ACESProxyContractsTests.swift` | `43947c798e6675b7a1e279dc2cf1f2f2fe3d821eeaeec5433320df1ec93e6d9d` |
| `verify-acesproxy-cube.py` | `ba655ec1da181e8b7c561a12541c44eef5de93f95cdf35d415981e4d06c8a0c3` |

## 数值验收

独立 Decimal 标量往返（代表值 `0.18`）的 10-bit 与 12-bit 误差均约为 `1e-80`；黑码、阈值、满码和非有限值拒绝均通过 `ACESProxyContractsTests`。

| 位深 | 网格 | 节点 | 最大尺度化误差 | RMS | P99 | 门槛 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 33³ | 35,937 | `5.551115123125783e-17` | `1.742067363865862e-17` | `5.551115123125783e-17` | `2e-12` |
| 10 | 65³ | 274,625 | `5.551115123125783e-17` | `1.419443207297696e-17` | `5.551115123125783e-17` | `2e-12` |
| 12 | 33³ | 35,937 | `5.551115123125783e-17` | `1.0803843155681211e-17` | `5.551115123125783e-17` | `2e-12` |
| 12 | 65³ | 274,625 | `5.551115123125783e-17` | `1.3333347243384459e-17` | `5.551115123125783e-17` | `2e-12` |

65³ 产物 SHA-256：

- 10-bit：`4668485cd2929609de721fdb474f73efdc6bada1b9d56a5ca45b06790220ffdf`
- 12-bit：`9f3353ca9f4c67ee01e4b5e76813da846530012e924a47281d593437428230d4`

## 实际命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`。最终日志 `/tmp/lutcalc-swift-test-final.log`，SHA-256：`582c4a73e542cee04d06a7232c97b242db7483673aa055a2c1d211b65af1e29c`。

```text
python3 -m unittest tests/native_batch_manifest_test.py
```

退出码 `0`，清单为 26 个预设。

```text
swift build --package-path Native/Packages/LUTKit -c release --product LUTReferenceCLI
python3 tools/native-validation/run-cube-batch.py \
  Native/Packages/LUTKit/.build/out/Products/Release/LUTReferenceCLI --workers 2
```

CLI 构建退出码 `0`；批量 CUBE 为 26 个预设 × 33³/65³，共 52 个生成/读回对，全部通过，统一门槛 `2e-12`。

```text
bash tools/native-validation/verify-native-release.sh
```

当前原生子集的静态边界检查、公式检查、项目/任务/用户 LUT 契约、三平台 Release 构建和 3 个 App 包资源审计通过。脚本最后因缺少真实全量发布验收清单 `docs/native-validation/full-scope-acceptance.json` 报未通过；该失败如实保留，未伪造清单。

## 未覆盖范围

本阶段只完成 ACESproxy 10/12-bit 解析式子集，不代表完整 H11 或全量迁移。相机/ISO/EI、CDL、Highlight Gamut、Knee、Limiter、完整 ICC、HDR/EDR、iPad 多窗口、真机 Files/File Provider、目标软件往返、任意 3D LUT 反求和完整发布清单仍未完成。Goal 继续保持 active。
