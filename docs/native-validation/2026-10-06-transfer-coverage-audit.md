# 公开传递公式生成路径覆盖审计

日期：2026-10-06。

本次审计交叉检查 `TransferID`、`AlgorithmCatalog`、`TransformPlan` 的输入解码分支和 `NativeOutputEncoder` 的输出编码分支。结果没有发现已登记公开公式但遗漏最终 Double 生成路径的传递函数。所有目录中的非参数化传递函数均由同色域计划实际实例化并执行有限值与往返检查；参数化 gamma 继续由专用契约覆盖。

## 实际命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'CatalogTransferSmokeTests|RegistryContractsTests|NativeOutputEncoderContractsTests|OutputCodeUnitsContractsTests'
```

结果：`CatalogTransferSmokeTests` 1 项、`OutputCodeUnitsContractsTests` 3 项、`RegistryContractsTests` 19 项通过；退出码 `0`。其中 19 个 33³/65³ 包装与独立 Decimal 误差检查的最大尺度化误差分别为 `4.440892098500626e-16`（独立 33³/65³）和 `7.993605777301127e-15`（旧调节链）。日志结果包位于 `artifacts/2026-10-06-transfer-coverage-audit/`，SHA-256：

`f496c204ba838a59d03e9b84f2b71298b021470168df7164100d18b9eee5c1a4`

## 仍未闭合

该审计只证明已有公式没有漏接，不等于完整迁移。`.labin` 仍为 `0/9`，直接查表注册仍为 `0/45`；任意 3D LUT 全局反求、自动 transfer/colour 分离、完整重建、资料不足的厂商变换、完整 ICC/HDR/OOTF、目标软件往返和发布清单仍未完成。

`FULL-01`、`FULL-03`、`FULL-05`、`FULL-07` 与 Goal 继续保持 active。
