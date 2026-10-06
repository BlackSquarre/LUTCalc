# Transfer 与 colour 缺口复核

日期：2026-10-06。

本次按算法优先范围复核了原生 Swift 的 transfer／colour 注册和执行路径，没有新增未经独立公开公式与参照支持的算法。

## 复核范围

- `TransferID`、`AlgorithmCatalog.builtIn()` 的传递注册、别名、来源和验证范围；
- `TransformPlan` 输入解码、输出编码以及 `NativeOutputEncoder` 的同色域 Double 路径；
- `ColorSpaceID`、`ColorPrimaries`、矩阵推导和 `ChromaticAdaptation` 的公开 CAT 分派；
- 已有 CIELAB、HLG、PQ、ACES RGC 数学子集及其明确拒绝边界；
- `docs/algorithm-only-audit.md` 与路线图中列出的资料阻塞项、`.labin` 和直接查表台账。

复核未发现已登记、已有公开连续定义、且当前实现缺少接线的 transfer 或 colour 公式。目录中的非参数化 transfer 均能通过同色域计划执行有限值往返；参数化 gamma 使用独立构造器和契约。剩余项目要么已有实现，要么缺少公开公式／单位语义／独立参照，不能安全猜测或以采样表替代。

## 实际命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'CatalogTransferSmokeTests|RegistryContractsTests|NativeOutputEncoderContractsTests|OutputCodeUnitsContractsTests'
```

工具链：SwiftPM Release，当前工作区 Apple Swift 工具链。

结果：25 项测试通过，0 失败，退出码 `0`。其中 `CatalogTransferSmokeTests` 1 项、`OutputCodeUnitsContractsTests` 3 项、`RegistryContractsTests` 20 项、`ProPhotoBBCRegistryContractsTests` 1 项。独立 Double 包装网格最大尺度化误差为 `4.440892098500626e-16`；既有调节链输出最大尺度化误差为 `7.993605777301127e-15`，均在现有门槛内。

## 未覆盖与不改变的状态

- 资料不足的厂商变换、`9/9` `.labin` 和 `45/45` 直接查表注册继续阻塞；本次没有创建替代算法或打包采样表。
- 自动 transfer／colour 分离、任意三维 LUT 全局反求、完整重建、完整 ICC/HDR/OOTF、目标软件往返和真实发布清单仍未完成。
- 白平衡的 Planck 轨迹、Duv/Dpl、PSST 与完整调节链仍不因本次复核而完成。
- UI、平台交互、真机性能和发布签名不在本工作包范围内。

本记录是范围复核，不代表任一 FULL 项或 Goal 完成。
