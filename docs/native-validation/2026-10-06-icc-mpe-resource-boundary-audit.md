# ICC MPE 资源与元素范围审计

## 范围

本次只审计 `ICCMPETransform` 的公开结构边界：`mpet` 元素表、元素
`offset/size`、共享元素范围、`curf`/`samf` 采样曲线、`matf` 动态矩阵、
`clut` 网格和资源算术。没有把未能由公开规范和独立参照同时证明的语义扩展
接入生产路径。

## 现状与结论

- `mpet` 元素数量限制为 `1...4096`，表大小使用溢出检查；元素 offset 必须
  位于元素表之后、四字节对齐且 `offset + size` 在 payload 内。
- 元素范围允许完全相同的共享范围；不同范围的交叠被拒绝。该策略保留了
  可共享元素，同时避免执行链读取重叠 payload。
- `curf` breakpoint 要求有限、归一化到 `0...1` 且严格递增；首段
  `samf` 拒绝，后续 `samf` 使用前段末值作为隐含首样本，末段以 `1.0`
  为上界。
- `matf` 的输入/输出通道、矩阵值数量及字节长度必须完全匹配；浮点值必须
  是有限的。
- `clut` 输入维度为 `1...16`，每个网格点为 `2...255`，其余网格头字节
  必须为零；值数量和字节长度使用 checked arithmetic，并要求精确落到元素
  末端。
- 执行前后均检查通道数和有限值，避免空向量、NaN/Inf 或超出 Float32
  可表达范围的中间结果绕过边界。

本轮没有发现同时满足公开 ICC 语义、独立参照和最小兼容承诺的新增生产修复。
动态矩阵元素的更宽泛厂商扩展、MPE 末端额外字节的填充语义以及完整真实
profile 逐码对照仍缺少足够公开证据，保留为研究阻塞；没有猜测性拒绝或放行。

## 实际验证

工具链：SwiftPM，当前 Xcode/Swift toolchain。

执行命令：

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCDeviceLinkContractsTests
git diff --check
```

结果：

- `ICCMPEContractsTests` Debug：28 项通过，0 失败。
- `ICCMPEContractsTests` Release：28 项通过，0 失败。
- `ICCDeviceLinkContractsTests` Release：7 项通过，0 失败。
- `git diff --check`：通过。

本记录只证明上述结构边界和已覆盖 device-link 子集；不代表完整 ICC、BPC、
gamut mapping、ColorSync、完整 MPE 元素集合或 Goal 完成。Goal 继续保持
`active`。
