# LUTAnalyst 四面体反求生产回放收紧验收

## 2026-10-05 当前源码复验

在三线性解析 Jacobian 改动后，对本文件所述四面体实现重新执行定向契约。Debug／Release 各 9 项通过、0 失败；没有修改四面体源码、插值轴序、Double 精度、条件数限制或 `2e-12` 残差阈值。

结果包：`artifacts/2026-10-05-lutanalyst-tetrahedral-revalidation/`。

SHA-256：

- `targeted-debug.log`: `dbcf34458e99f2fdafa60b6bbdcc61bfe200d6b8d6178ab37df746d316c62c2e`
- `targeted-release.log`: `4cd570b6ab382d7512ad905b83488d46091d7ed67c2eeb621cf5e18e71a8605b`
- 两个 `.exit` 文件：`9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

## 范围

本轮只收紧已有 `Tetrahedral3DInverse` 子集的根接受条件。局部四面体仿射方程仍只负责产生候选；候选现在必须再次通过生产 `LUTVolume3D.sample(..., interpolation: .tetrahedral, outside: .reject)`，并在 `2e-12` 相对尺度阈值内回放。没有改变 LUT 网格、插值轴序、Double 精度或阈值。

## 契约

- 恒等网格、折叠双根、域外无解、退化未决、仿射矩阵独立参照和拒绝边界继续通过。
- 新增相邻四面体边界根去重，避免同一输入坐标重复报告。
- 新增非单位输入域坐标回映射，验证报告结果回到 `LUTDomain` 而不是归一化坐标。
- 生产 sampler 回放失败或残差超限的候选不接受；奇异／病态单元仍报告 `unresolved`。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter TetrahedralInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter TetrahedralInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release
```

定向 Debug／Release 各 9 项通过，0 失败，退出码 `0`。此前记录的全量 Release 为 8 个测试包、733 项执行、0 失败，其中 `LUTAnalysisTests` 65 项；当前源码复验的全量计数见上方复验记录，避免将历史计数当作当前结果。

macOS、generic iOS、generic iOS Simulator 的未签名 Release `xcodebuild` 均退出码 `0`，日志均包含 `BUILD SUCCEEDED`。

结果包：`artifacts/2026-10-05-lutanalyst-tetrahedral-replay/`。

SHA-256：

- `targeted-debug.log`: `47ae79316985fdb11a65690bceb5a16fa3eb6048f50c5f39fd07ac254156508e`
- `targeted-release.log`: `a7fe47f03d5276aa4798c776ff84bb227eec8255463bd8e41b214dd880362d10`
- `full-release.log`: `283a45ae82af2ea0b644b281d4b07cc574a1edc597fc6c2a567c42266afe4d7e`
- `macos-release.log`: `427d5c0b7e8f496df6c568a08c1360514e84fe78a7608bedc50a66326d989b70`
- `ios-release.log`: `843944cbb48b3846cc4be0fb4e1b8d1521939029cf1a1186274623b3ed5abdb1`
- `simulator-release.log`: `bc524a186c28eaee6fd40b33688f8ef24c1237d95a619d7f2e841ae8b824232d`
- 所有 `.exit` 文件：`9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

## 未覆盖

本轮不代表任意连续 3D LUT 的全局唯一性，不接通 tricubic、组合 shaper、自动 transfer／颜色分离、完整重建、项目持久化或目标软件往返。9 个 `.labin`、45 个直接查表注册、完整 HDR／ICC、UI、设备性能和发布验收继续保持原状态；FULL-05、H10 与 Goal 继续为 `active`。
