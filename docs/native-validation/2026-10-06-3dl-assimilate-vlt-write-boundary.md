# 2026-10-06 3DL、Assimilate 与 VLT 写出边界复核

本轮只复核公开格式子集的写出量化和拒绝边界，不扩大厂商方言兼容承诺，也不引入厂商 LUT、旧 `.labin` 或等价采样表。

## 契约与实现

- `.3dl` Flame、Lustre、Kodak writer 继续使用正值 half-up 量化：`floor(v * (2^bits - 1) + 0.5)`。负值、超白、非有限值和无法无损表示的输入返回 `lossyRepresentation`。
- 新增 `ThreeDLContractsTests.testWriterMatchesIndependentPositiveHalfUpReference`，直接以独立整数公式核对 12-bit 端点、半码、非整数码和中点样本；不依赖旧 JavaScript 或 writer 输出作为参照。
- Assimilate `.lut` 保持公开的 `LUT: 3 N`、4096 点子集和既有正值 half-up 规则；标题、shaper、非 unit 域等不可表示状态继续拒绝。
- VLT 保持 Panasonic 17^3、12-bit、R-fast 节点顺序和 unit 域限制；非 17^3、越界、非有限和非 unit 域继续拒绝。

## 验证

命令：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ThreeDLContractsTests/testWriterMatchesIndependentPositiveHalfUpReference
```

结果：退出码 `0`，新增测试 `1/1` 通过。此前完整 `ThreeDLContractsTests` 已覆盖 11 项；本次新增独立量化契约后定向测试通过。

本记录不代表目标调色软件导入、真实厂商文件变体、iCloud/File Provider 或完整发布验收已完成；这些范围继续保持未完成。
