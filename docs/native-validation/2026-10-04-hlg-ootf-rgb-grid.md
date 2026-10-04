# 2026-10-04 HLG OOTF RGB 全网格核验

## 范围

本记录只核验现有 `HLGOOTF` 已声明参数的显示域标量和 RGB 数学子集。没有新增 HDR 变体、自动峰值、参考白／黑位推断、屏幕 EDR 路径或 PQ OOTF 语义。

## 契约先行

新增 `HLGOOTFGridContractsTests`，独立重写 HLG OOTF 的系统 gamma、黑位、峰值、BBC 系数和 Rec.2020 luma 耦合，不调用生产实现的辅助方法。首次 Release 定向执行时，独立逆参照在全黑点计算 `0` 的负指数，触发 `nonFinite`；该红灯只暴露参照边界缺失，保留在首次日志中，没有把它计为生产实现失败。

修正独立参照的全黑边界后，重新执行：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter HLGOOTFGridContractsTests \
  2>&1 | tee /tmp/lutcalc-hlg-ootf-grid-contracts-20261004-r2.log
```

结果：退出码 `0`；2 项通过。33³ 与 65³ 共 `931,686` 个通道，前向和逆向独立参照最大尺度化误差均为 `0`。标量分支、BBC 系数和峰值裁剪也通过。

定向日志 SHA-256：

`d93eeba1c81fd8dae44ea0a75955189b85515a1e7320489a2da7347e804616cf`

## 全量回归

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  2>&1 | tee /tmp/lutcalc-hlg-ootf-grid-full-release-20261004.log
```

工具链为 Xcode 27.0、Swift 6、macOS arm64。8 个测试包共执行 `731` 项，失败 `0`；LUTFormats 的旧 `.labin` 和 NCP 外部夹具各 1 项继续按原设计跳过。各包为 LUTSharedUI `162`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `56`、LUTCore `232`、LUTCatalog `24`、LUTAnalysis `32`。

完整日志 SHA-256：

`19ee1899d8267a358d0a0bf9448c15c1a8ac1d3e9bc6406490e49939530777c2`

新增测试源码 SHA-256：

`fb4d83d16c287984a2781b3ff63d6db616c521202627c02ae82edbc1785b6850`

## 未覆盖范围

这项证据只关闭 HLG OOTF 已声明参数的 RGB 全网格数值核验，不代表完整 HDR/OOTF 完成。以下仍未完成：自动峰值准备、参考白／黑位策略、四种 HDR 显示变体、PQ OOTF 的输入单位／`Lw`／scale 语义、完整 HDR 限幅和裁剪统计、真实 HDR/EDR 屏幕参照、完整 ICC、LUTAnalyst、真机性能、UI 和发布清单。Goal 保持 active。
