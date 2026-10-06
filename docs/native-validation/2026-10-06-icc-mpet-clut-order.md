# ICC MPE CLUT 维度顺序验收

## 范围

本轮修正用户导入 ICC `multiProcessElementsType` 的 `clut` 展平顺序。ICC.1:2022-05 §10.16.2.4 规定第一输入维度变化最慢，最后输入维度变化最快；该边界不涉及任何内置厂商 LUT 或采样表。

## 先行失败契约与修复

旧实现把第一维当作最快维度。原有所有 2 点网格夹具对转置不敏感，因此新增非均匀 `[2,3,2]` 网格夹具，每个输出通道写入展平索引。输入 `(1,0,0)` 按规范应命中索引 `6`，旧方向会命中索引 `1`；修复后命中 `6`。

生产代码以后续维度乘积计算 stride，保持 CLUT 输入仍只在元素内部裁切至 `0...1`，不改变 MPE 元素间不裁切规则。

## 实际命令与结果

工具链：macOS Swift Package Manager，Swift 6.x，Debug／Release。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMPEContractsTests/testCLUTUsesFirstDimensionLeastRapidOrderForNonUniformGrid
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests/testCLUTUsesFirstDimensionLeastRapidOrderForNonUniformGrid
git diff --check
```

结果：Debug 与 Release 定向测试各 1 项通过，退出码 0；`git diff --check` 通过。

## 未覆盖范围

本记录不证明完整 ICC profile class、rendering intent、BPC、gamut mapping、ColorSync、第三方 profile 逐码参照、所有未来 MPE 元素、HDR/EDR 或 LUTAnalyst 任意三维全局反求已经完成；这些范围继续保持未完成，Goal 不标记 complete。
