# 2026-10-06 并行算法闭合与回归

## 本轮闭合项

- `ICCMFTTransform` 的 `mft1/mft2` 网格点按 ICC.1 字段规范接受 `2...255`；仍保留 checked product/sum 和 16 MiB 资源上限。255 点一维夹具误差小于 `2/65535`。
- LUTAnalysis 增加非单位域严格单调分段线性独立参照：节点 `[10,20,40]`、域 `[-2,1,4]`，`x=2.5` 得到 `y=30`，逆回 `x=2.5`，误差不超过 `2e-12`。生产实现无需调整。
- PQ OOTF 复核未发现公开唯一公式；新增 80 位 Decimal 边界探针，保留研究阻塞，不猜测生产算法。

## 实际验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter MonotonicAnalysisContractsTests
swift test --package-path Native/Packages/LUTKit -c release
git diff --check
```

- ICC 定向：15/15，通过 0。
- 单调分析定向：5/5，通过 0。
- 完整 LUTKit Release：LUTAnalysis 94/94，其余测试套件均通过，失败 0。
- `git diff --check` 通过。

## 仍未完成

本轮没有关闭任意 3D 全局反求、tricubic 全根隔离、自动 transfer/colour 分离与完整重建、完整 ICC 的 BPC/gamut mapping/ColorSync、PQ OOTF 场景到显示语义、`.labin` 9 项替代或直接查表 45 项替代。Goal 保持 active。
