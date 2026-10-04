# DJI X3 D-Log legacy 算法验收

日期：2026-10-04

## 范围与来源

本阶段只闭合旧 `js/gamma.js` 注册项 `DJI X3 DLog` 的 `LUTGammaLogClip` 一维软肩部解析式。参数和分段顺序直接来自旧注册表：`[0.188272019,-0.011778504,0.473218054,6.086793376,10,0.419294419,0.169033387,0.095812746,0.00625,0.902863937,1.59668525,22.90700861,-17.39462704]`。实现使用 Swift `Double`，不携带旧采样表、厂商 LUT 或 `.labin`。

编码端依次使用线性肩部、十进制对数段和低端仿射段；解码端依次使用二进制肩部、十进制对数段和低端仿射段。`1.59668525` 与 `0.902863937` 分别是编码和解码肩部边界，不能互换。

## 契约与命令

- 新增 `DJIX3DLogTransfer`、稳定 `TransferID.djiX3DLogLUTCalcLegacy`、目录来源描述和一档曝光预设。
- `DJIX3DLogContractsTests`：3 项通过，覆盖旧 JavaScript 参照、分界、非有限值、计划边界、目录身份与 Data 编码分类。
- 旧 JavaScript 只生成固定 JSON 参照：`tests/fixtures/native-contracts/dji-x3-dlog-reference.json`。

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter DJIX3DLogContractsTests
swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
for n in 17 33 65; do
  python3 tools/native-validation/verify-dji-x3-dlog-cube.py \
    "docs/native-validation/artifacts/2026-10-04-dji-x3-dlog-contracts/dji-x3-$n.cube"
done
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-dji-x3-release-20261004.log 2>&1
```

## 独立 Decimal 结果

校验器独立实现 90 位 Decimal 公式，不调用生产 Swift。首次校验发现肩部解码参数元组顺序错误，修正 `tools/native-validation/verify-dji-x3-dlog-cube.py` 后重新执行全部网格；生产公式和 CUBE 未因该修正改变。

| 网格 | 通道样本 | 最大绝对误差 | 阈值 |
| ---: | ---: | ---: | ---: |
| 17³ | 14,739 | `1.4191241664030469702e-16` | `3e-15` |
| 33³ | 107,811 | `1.9095204480342102581e-16` | `3e-15` |
| 65³ | 823,875 | `1.9095204480342102581e-16` | `3e-15` |

结果包位于 `docs/native-validation/artifacts/2026-10-04-dji-x3-dlog-contracts/`，包含 17³、33³、65³ CUBE；这些文件是验证产物，不是产品内置资源。

## 回归与目录

- 定向 Swift 契约：3 项通过。
- Swift Release 全量：8 个 XCTest 包共 723 项执行、0 失败、2 项既有可选外部夹具跳过；原始日志 `/tmp/lutcalc-dji-x3-release-20261004.log`，SHA-256 `177f66a1344af9b70296dc6af30825d04c971389a838f9805f65e3016738729f`。
- `LUTCatalogChecks`：75 曲线、20 色域、71 预设通过。

## 未覆盖范围

本记录不证明 DJI X3 的完整 D-Gamut、相机曝光／ISO 行为、DJI DLog-M、完整设备模型、HDR/OOTF、第三方软件往返、性能或签名发布。其余直接查表注册项、9 个 `.labin` 资源、完整 ICC／LUTAnalyst／格式互操作和真实全量清单继续未完成；UI 按用户要求暂缓，Goal 保持 active。
