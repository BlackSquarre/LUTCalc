# LUT 格式 unsupported 分支边界

日期：2026-10-06。

## 复核结论

逐一检查 SPI3D、3DL、Assimilate `.lut` 和 VLT 的 `unsupported` 分支，没有发现能够仅依据公开语法、在现有 Swift/`Double` 路径中无损闭合的新子集：

- SPI3D 的未知版本和非 RGB 通道布局缺少兼容语义，继续拒绝。
- 3DL 的 `3DMESH`、`LUT8` 和 `gamma 1.0` 是 Lustre 方言标记；在 Flame/Kodak 入口继续拒绝，避免把方言混读。
- Assimilate `.lut` 的通道数目前只安全支持公开的 1 或 3 通道；未知通道布局没有独立块序和量化参照，继续拒绝。
- VLT 的 Panasonic 版本和 17³ 网格是当前已核实子集；其他版本或网格没有独立设备/软件参照，继续拒绝。

## 契约与结果

新增 `UnsupportedFormatVariantContractsTests`，覆盖上述四类拒绝边界：SPI3D 版本/布局、3DL 方言错配、Assimilate 未知通道数和 VLT 版本/网格。执行：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter UnsupportedFormatVariantContractsTests
```

结果：Release 定向 `4/4` 通过，失败 `0`，退出码 `0`。

本轮没有修改生产解析或写出算法，没有引入厂商 LUT、旧 `.labin` 或等价采样表。目标软件互操作、私有方言、NCP 写出、`.labin`、直接查表和完整 FULL-06 仍未完成。
