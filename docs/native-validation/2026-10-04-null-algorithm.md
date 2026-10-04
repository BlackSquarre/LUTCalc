# Null legacy 算法验收

日期：2026-10-04

## 范围与来源

本阶段只闭合旧 `js/gamma.js` 的 `LUTGammaNull` 注册。它没有厂商采样表或设备色域语义：前向是线性 legacy 值的共享 Legal/Data 包装，逆向是对应仿射逆。实现为 Swift `Double`，来源为 `js/gamma.js:LUTGammaNull linToData/linFromData`，不读取 JavaScript、`.labin` 或任何 LUT 资源。

## 契约、实现与命令

- 新增 `NullTransfer` 和稳定身份 `null.lutcalc-legacy.v1`。
- 接入 `TransformPlan`、`NativeOutputEncoder`、Data 单位分类、目录和一档曝光预设 `null.legacy-exposure-one.v1`。
- `NullTransferContractsTests`：3 项通过，覆盖前向/逆向包装、非有限值、计划往返、目录身份和 Data 编码分类。

先行契约在实现前因缺少 TransferID 退出 1；实现后使用以下命令验证：

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter NullTransferContractsTests
swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
for n in 17 33 65; do
  swift run -c release --package-path Native/Packages/LUTKit LUTReferenceCLI \
    --size "$n" --output "docs/native-validation/artifacts/2026-10-04-null-contracts/null-$n.cube" \
    --preset null.legacy-exposure-one.v1
  python3 tools/native-validation/verify-null-cube.py \
    "docs/native-validation/artifacts/2026-10-04-null-contracts/null-$n.cube"
done
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-null-release-20261004-r2.log 2>&1
```

## 独立 Decimal 结果

校验器独立使用 80 位 Decimal。该预设的一档曝光解析后再编码可化简为 `output = 2 * input - 0.06256109481916`；校验器仍逐节点重读完整 CUBE，不调用生产 Swift。

| 网格 | 通道样本 | 最大绝对误差 | 阈值 |
| ---: | ---: | ---: | ---: |
| 17³ | 14,739 | `2e-16` | `3e-15` |
| 33³ | 107,811 | `3e-16` | `3e-15` |
| 65³ | 823,875 | `3e-16` | `3e-15` |

## 回归结果

- 定向 Swift 契约：3 项通过。
- 目录契约：76 曲线、20 色域、72 预设通过。
- Swift Release 全量：本轮日志完成全部测试包，所有 `All tests` 套件通过、0 失败；既有外部夹具仍按设计跳过。日志 `/tmp/lutcalc-null-release-20261004-r3.log`，SHA-256 `5267e5ca94228d551bd24474c0b004b42cc38c4bfc606bdcd89e4ba0c2059445`。目录日志 `/tmp/lutcalc-null-catalog-20261004.log`，SHA-256 `5b08300224b6770c0675272073c0e698c1b2477fe1035eb97b56ff7fed4b2e03`。

## 未覆盖范围

本阶段不代表旧 Null 之外的完整调节链、HDR/OOTF、ICC、LUTAnalyst、格式互操作、相机设备语义、提供商故障、UI、性能预算、签名发布或真实全量清单完成。Goal 保持 active。
