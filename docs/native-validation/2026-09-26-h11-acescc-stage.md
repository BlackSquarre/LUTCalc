# H11 ACEScc 阶段验收

日期：2026-09-26

## 范围

本阶段补齐覆盖调查中记录的 ACEScc 解析式。实现只使用公开 ACEScc 分段公式和 `Double`，不携带旧 `.labin`、厂商 LUT 或采样数组。输入/输出色彩空间固定为 ACES AP1；旧网页的 0.9 数据缩放不混入官方 ACEScc 条目。

## 修改

- `Native/Packages/LUTKit/Sources/LUTCore/ACESCCTransfer.swift`
- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift`
- `Native/Packages/LUTKit/Sources/LUTCatalog/AlgorithmCatalog.swift`
- `Native/Packages/LUTKit/Sources/LUTReferenceCLI/main.swift`
- `Native/Packages/LUTKit/Sources/LUTCatalogChecks/main.swift`
- `Native/Packages/LUTKit/Tests/LUTCoreTests/ACESCCContractsTests.swift`
- `Native/Packages/LUTKit/Tests/LUTCatalogTests/RegistryContractsTests.swift`
- `tools/native-validation/verify-acescc-cube.py`
- `tools/native-validation/run-cube-batch.py`

## 公式与独立参照

ACEScc 编码使用 `log2(2^-16 + 0.5·linear)` 的低段、`(log2(linear)+9.72)/17.52` 的主段、`2^-15` 切点、负值码 `-0.3584474886` 和 65504 上限。独立 Python verifier 以 80 位 `Decimal` 重算解码、曝光乘 2 和再编码；Swift 测试覆盖切点、负值、上限、逆函数、非有限输入与同空间计划。

## 实际命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c release
```

通过。完整 Swift Release 回归日志：`/tmp/lutcalc-acescc-swift-release.log`，SHA-256：`54cd8b879989c72c4bdb5ffbccb149227f30dd1f1f23e3b187b2f992bbf5cfb7`。Swift Release 测试清单为 291 项；新增 ACEScc 定向测试 4 项、目录身份契约 1 项通过；全包其余测试无失败。

```text
python3 tools/native-validation/run-cube-batch.py \
  Native/Packages/LUTKit/.build/out/Products/Release/LUTReferenceCLI --workers 2
```

通过，48 个 33³/65³ 生成与独立读回对全部通过，其中 ACEScc 两个网格的独立结果为：

| 网格 | 节点 | 最大尺度化误差 | RMS | P99 | 门槛 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 33³ | 35,937 | `1.1102230246251565e-16` | `5.2331768739506437e-17` | `1.1102230246251565e-16` | `2e-12` |
| 65³ | 274,625 | `1.1102230246251565e-16` | `4.87549176673044e-17` | `1.1102230246251565e-16` | `2e-12` |

批量日志：`/tmp/lutcalc-acescc-batch.log`。

```text
swift run --package-path Native/Packages/LUTKit -c release LUTCatalogChecks
```

通过，注册表现在为 42 条曲线、13 个色域、27 个预设；稳定 ID、来源、别名、悬空引用和重复项检查通过。

## 平台与未覆盖范围

本阶段源码位于共享 Swift Package，未改动平台专属代码；已有 macOS、iOS Simulator、iOS generic Release 构建结果仍有效，但本阶段没有新增真机 ACEScc 数值或系统文件面板证据。完整 ACES 旧链、相机范围、HDR/EDR、完整 H11 覆盖和发布清单仍未完成，Goal 保持 active。

## 合并发布检查

`bash tools/native-validation/verify-native-release.sh` 已重新运行。公式检查、CUBE 生成/读回、Swift Release、macOS Release、iOS Simulator Release、iOS generic Release 和 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-acescc-native-release-final.log`，SHA-256：`48867ede65a0c58c95b01123f3fd386a198f1c89ffda1615a433943bcdb993c0`。入口退出码为 `2`，唯一失败为缺少真实 `docs/native-validation/full-scope-acceptance.json`；未伪造该清单。
