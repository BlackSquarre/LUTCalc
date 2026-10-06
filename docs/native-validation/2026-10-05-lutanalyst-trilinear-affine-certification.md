# LUTAnalysis Trilinear3DInverse 严格仿射单元验收

## 范围

本工作包只处理 `Trilinear3DInverse` 对严格仿射 3D LUT 单元的局部判定。单元的二阶混合差分和三阶混合差分在容差内为零时，使用角点基向量构成的 3×3 `Double` 矩阵直接求解局部坐标；非奇异矩阵且解落在单位单元外时，可以证明该单元无解。矩阵奇异时仍报告 `unresolved`，没有把多解或连续根误判为唯一根。

本工作包没有扩展任意非线性 3D LUT 的全局反求，也没有修改路线图和总范围审计。

## 失败契约

新增 `testStrictAffineCellCertifiesNoSolutionOutsideParallelepiped`。测试构造严格仿射单元：

```text
out.r = r + 0.5*g
out.g = g + 0.5*b
out.b = b + 0.5*r
```

目标值位于每个通道的角点包围范围内，但其仿射逆坐标包含 `q.r > 1` 和 `q.b < 0`。旧实现依赖有限 Newton 种子，结果为 `unresolved`；契约要求非奇异严格仿射单元直接证明 `noSolution`，且 `unresolvedBoxCount == 0`。

## 实现

- 对三个二阶混合差分和一个三阶混合差分做容差判定。
- 对确认严格仿射的单元使用角点 `c[1]-c[0]`、`c[2]-c[0]`、`c[4]-c[0]` 构造矩阵。
- 矩阵可逆时求解局部坐标，并在单位单元外稳定返回该单元无解。
- 单位单元内的候选仍经生产 `LUTVolume3D.sample(..., .trilinear)` 回放确认。
- 奇异矩阵、回放失败或残差超阈值继续记为 `unresolved`。

## 实际验证

工具链：Xcode Swift 6，macOS 27 SDK，SwiftPM `LUTKit`。

命令：

```bash
cd Native/Packages/LUTKit
swift test -c debug --filter TrilinearInverseContractsTests
swift test -c release --filter TrilinearInverseContractsTests
git diff --check -- Native/Packages/LUTKit/Sources/LUTAnalysis/Trilinear3DInverse.swift Native/Packages/LUTKit/Tests/LUTAnalysisTests/TrilinearInverseContractsTests.swift
```

结果：

- Debug：`TrilinearInverseContractsTests` 11 项通过。
- Release：`TrilinearInverseContractsTests` 11 项通过。
- `git diff --check`：通过。
- 构建期间仅出现既有的 `ICCMFTContractsTests.swift` 未变变量和 `UserLUTProjectAssetContractsTests.swift` 多余 `try` 警告；没有新增错误。

## 未覆盖范围

- 非线性三线性单元的跨单元多根、切向根和全根完备性仍可能为 `unresolved`。
- 严格仿射但病态或奇异的矩阵仍不作唯一性或无解证明。
- 本记录不证明任意 3D LUT 全局反求已经完成。
