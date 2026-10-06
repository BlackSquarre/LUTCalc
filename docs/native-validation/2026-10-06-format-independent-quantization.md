# LUT 格式独立量化与剩余算法边界复核

日期：2026-10-06。

## 范围

本轮复核 `NCP 0100`、VLT、3DL（Flame/Lustre/Kodak）和 Assimilate `.lut` 的纯 Swift/`Double` 解析与写出边界。重点检查是否存在不依赖 UI、目标调色软件或厂商私有采样数据即可闭合的算法缺口。

## 新增独立契约

新增 `FormatIndependentQuantizationContractsTests`，以独立的 `R-fast` 三维索引和 12-bit `round(.toNearestOrAwayFromZero)` 公式核对 VLT writer 的全部 `17^3 = 4913` 节点。参照不调用 parser，也不把 writer 输出作为期望值；逐节点、逐通道比较文本整数结果。

## 实际验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter FormatIndependentQuantizationContractsTests
```

结果：SwiftPM Release 构建成功，独立契约 `1/1` 通过，失败 `0`，退出码 `0`。

## 算法结论

- VLT 的公开 17³、12-bit、R-fast 规则已有完整独立逐节点参照；没有新的安全实现缺口。
- 3DL 三方言当前公开子集的轴序、正值 half-up 量化、shaper 和拒绝边界已有契约；厂商扩展仍需要目标软件或受控样本，不能猜测扩大。
- Assimilate `.lut` 当前 1D、固定通道块和整数编码子集已有独立边界；完整厂商方言及目标软件往返未证实。
- NCP 0100 只能证明观察到的 638 字节只读布局。写出仍缺少机型/固件/工具版本样本、字段差异、软件读回和相机导入证据；继续保持 `.writeUnsupported`。

本轮没有改动生产格式算法，也没有引入厂商 LUT、旧 `.labin` 或等价采样表。`.labin` 算法替代、直接查表替代、LUTAnalyst 任意三维全局反求和真实目标软件互操作继续未完成。
