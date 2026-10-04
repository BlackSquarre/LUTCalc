# H13 ICC 参数曲线类型 1/2 CPU 阶段验收

日期：2026-09-26

## 范围

本批在既有 ICC RGB matrix/TRC CPU 子集上增加 ICC `para` function type 1 和 2 的解析式求值与逆函数。仍只处理 RGB/XYZ、矩阵/TRC、CPU Double 路径，不执行完整 ICC 工作空间管理，不保存任何采样曲线或 LUT 资源。

## 失败契约

先加入 `ICCMatrixTRCContractsTests.testParametricTypesOneAndTwoMatchIndependentReferences`，随后执行：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests
```

实现前按预期失败：类型 1 在 `ICCMatrixTRCTransform` 中返回 `unsupportedCurve("para:1")`。

契约要求：

- type 1 按 `Y=(aX+b)^g` 及阈值 `X >= -b/a`，低段为 0；
- type 2 按 `Y=(aX+b)^g+c` 及相同阈值，低段为 `c`；
- 输入和输出均使用 ICC payload 解码后的 Double 参数，逆函数保持可复现；
- type 3 及其余未完成曲线继续明确拒绝；
- 不改变既有 `curv(count=1)`、type 0/type 4、矩阵、域门控和 provenance 语义。

## Swift Double 实现

`ICCMatrixTRCTransform.swift` 新增：

- `Curve.parametricOne([Double])` 与 `Curve.parametricTwo([Double])`；
- type 1/2 参数数量、正指数、正 `a` 的构造边界；
- 编码阶段分别实现解析逆函数，低段采用确定性的阈值代表值；
- type 3 和其他未覆盖形式保持 `unsupportedCurve`。

## 定向结果

- `ICCMatrixTRCContractsTests`：6 项通过；
- type 1/type 2 独立参考通过，type 2 的 `c` 按 ICC s15Fixed16 载荷量化值比较；
- 既有 33³/65³ gamma 往返、缺标签、非 RGB/PCS、type 3 拒绝和域外输入契约保持通过。

## 结论边界

本批只扩展两个可追溯的 ICC 参数曲线类型。完整 ICC tag 类型、采样型 `curv`/LUT、工作空间与显示转换、Core Image/Metal、HDR/EDR、整图显示、真机和发布清单仍未完成。
