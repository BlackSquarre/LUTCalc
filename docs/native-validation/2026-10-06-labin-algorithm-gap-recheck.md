# 2026-10-06 `.labin` 算法替代缺口复核

## 范围

本轮只复核根目录九个旧 `.labin` 研发夹具是否能从现有实现和可追溯资料恢复为 Swift `Double` 连续算法。用户主动导入 `.labin` 的解析、量化读写和分析路径不在内置算法替代范围内；不把旧资源内容复制到 Swift、压缩文件、纹理或拟合系数中。

## 逐项结果

以下九个夹具均通过现有 `LABinParser` Release 兼容契约，但没有因此获得连续公式、版本化设备范围、非灰轴语义或独立全域参照：

| 夹具 | 解析契约 | 算法替代 |
| --- | --- | --- |
| `AlexaX2.labin` | 通过 | 阻塞 |
| `Amira709.labin` | 通过 | 阻塞 |
| `Cine709.labin` | 通过（按旧有损边界处理） | 阻塞 |
| `LC709.labin` | 通过 | 阻塞 |
| `LC709A.labin` | 通过 | 阻塞 |
| `V709.labin` | 通过 | 阻塞 |
| `cpoutdaylight.labin` | 通过 | 阻塞 |
| `cpouttungsten.labin` | 通过 | 阻塞 |
| `s709.labin` | 通过 | 阻塞 |

旧 JavaScript 只提供查表资源加载和调用关系，没有公开的连续非灰轴定义；仓库现有说明也明确 LC709、LC709A、s709、V709、ARRI 709 变换来自 look profile 或估算过程。Canon CP IDT 还缺少版本化矩阵、色调处理和独立参照。因此不能把灰轴曲线、有限节点或旧资源行为外推为厂商算法。

## 实际命令和结果

工具链为 Xcode 27、Swift 6、macOS arm64。对每个文件分别执行：

```sh
LUTCALC_LABIN_SAMPLE="$PWD/<name>.labin" \
  swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisFileContractsTests/testLegacyLABinFixtureIsParsedOrReportsLossyBoundary
```

九个文件均退出码 `0`，每次选定测试执行 `1` 项、失败 `0`。汇总日志：`/tmp/labin-gap-recheck-20261006.log`；SHA-256：
`f8a74d2e2b94cc274d45e8f2ec4d2df887c15e1fe3fa0f2441c0737ddaa8e864`。

## 结论

`.labin` 算法替代保持 `0/9`，不新增目录身份、默认路由或内置资源。只有取得厂商连续公式、适用版本/机型、非灰轴语义和独立 `17^3/33^3/65^3` 参照后，才可先补失败契约，再实现 Swift `Double` 路径。Goal 继续保持 `active`。

