# 2026-10-03 3DL 批量 flavor 与项目预设后端验收

## 结论和范围

原生单文件导出已支持 Flame／Lustre／Kodak grammar，但此前批量请求、exporter 和项目预设未提供该选项，实际批量固定为 Flame。本轮接通三种既有 grammar 的不可变请求、恢复身份、直接／checkpoint staging 执行和项目预设持久化。

UI 继续暂缓；本轮没有设备或界面操作。该成果只关闭本地 3DL flavor 传递和 schema 24 后端子集，不代表 FULL-06/FULL-08、H07/H08/H12/H14 或整体 Goal 完成。真实全量清单仍缺失，发布证据检查退出 2。

## 契约先行与实际实现

先新增七项 `ExposureBatchThreeDLFlavorContractsTests` 契约。第一次编译红灯包含缺少 API 和两处测试的 async autoclosure 错误；修正测试诊断代码后重新运行，`red-api.log` 仍退出 1，原因是请求／预设／exporter 缺少 flavor API 与算法身份。本次红灯属于 API 不存在的编译证据，没有 XCTest 执行计数，不描述为运行时数值失败。

随后实现：

- `ThreeDLFlavor` 增加 Codable，并登记 `native.3dl-batch-flavor.v1` 身份。
- `ExposureBatchRequest.threeDLFlavor` 默认为 Flame；非 `.3dl` 与非默认 flavor 组合在请求构造时拒绝。
- `ExposureBatchExporter` 增加显式 flavor 入口。旧适配器默认实现只允许 Flame；Lustre／Kodak 在调用旧 exporter 前明确失败，不静默丢失选择。
- 直接批量和 durable checkpoint 的 staging 路径均把 flavor 及各自覆盖政策传给 NativeExportService，再进入已有 FileCubeSink／ThreeDLWriter。没有改动现有 10 位输入／12 位输出、网格、Double、插值和原始 grammar。
- Flame 不增加 fingerprint 字节段，冻结的此前默认请求 fingerprint 仍为 `053beb449842948f76f1df1954d3a4af950cdbc61cbabd1b1987be9dc49e86cc`。Lustre／Kodak 追加长度分隔的版本／flavor 段；变更 grammar 后旧 report／checkpoint 不接受恢复。
- `ExposureBatchPreset` 保存 flavor，文稿后端的显式请求及存储预设重建均接通；目录和 allowOverwrite 仍是调用方任务输入，不写入项目授权。

第一次实现后编译因 ProjectManifest 缺少 LUTFormats import 退出 1，补齐 import 后 Debug 七项通过。随后补覆盖授权契约，在新证据目录运行最终 Debug 八项通过。所有失败／修复日志保留，不以绿灯覆盖历史失败。

## 项目 schema 24

新项目写出 schema 24；非 nil 预设必须含合法 `threeDLFlavor`。3DL 预设同时保存 `algorithmVersions.exposureBatchFormat = native.3dl-batch-flavor.v1`。

schema 16–23 原有批量预设没有 flavor，读取到内存时迁移为 Flame 并补齐格式算法身份。旧 schema 偷带新字段／身份、schema 24 缺字段／null／未知 flavor、重复 JSON 键、未知算法身份和非 3DL 组合均拒绝。schema 1–15 仍不得携带批量预设。既有模拟旧 schema 的测试夹具移除本轮新增身份，以保持其代表真实旧 schema；未放宽旧字段检查。

实际创建并读取 schema 23 `.lutcalc` 包，迁移后源 manifest 字节不变。新 schema 24 三种 flavor 的项目 JSON、磁盘保存／重开、撤销／重做，以及文稿后端重建请求身份均通过。读取迁移不自动写回；用户显式保存使用新 schema。

## 八项后端契约

| 契约 | 实际覆盖 |
| --- | --- |
| 请求身份 | 三种 flavor 身份分离；默认／显式 Flame 与已验收旧 fingerprint 一致；其他七格式拒绝非默认 flavor |
| 非线性完整网格 | 三 flavor × 17³/33³/65³ × 两曝光，检查全部节点、非线性 shaper 和 Lustre Mesh／尾段 |
| 检查点恢复 | Lustre 第二项故障注入后重开 store/coordinator；更改 Kodak 拒绝 report／checkpoint；原请求恢复，首文件字节／report 保留 |
| 旧 exporter | 非默认选择在调用旧方法前失败、零输出；Flame 仍可正常生成 |
| 覆盖授权 | 默认拒绝已有 Lustre 目标并保留字节；显式授权后以完整 33³ 替换原 17³ 输出，grammar 保留且无临时条目残留 |
| 项目往返 | 三 flavor schema 24 JSON、真实磁盘项目、undo/redo；实际 schema 23 读取迁移保留源字节 |
| 严格结构 | 非法／null／缺失 flavor、旧 schema 偷带字段／身份、重复 JSON、错误算法和非 3DL 组合拒绝 |
| 文稿后端 | 三 flavor 项目包磁盘重开后请求身份不变；启动前捕获的请求不被后续预设清除影响；实际批量回读 |

中断为 exporter 在第二项抛出 `CancellationError`；不作为实际 SIGKILL、后台终止、真实 Task 取消延迟或 File Provider 的证据。

## 独立数值与 grammar 验证

独立脚本 [`verify-batch-3dl-flavor.py`](../../tools/native-validation/verify-batch-3dl-flavor.py) 使用 Python 标准库 Fraction，从有理数产生二次输入 shaper、曝光 1/2／1 和 12 位输出参照，直接解析原始文本，不调用 Swift 或旧 JavaScript。

最终 Debug／Release 各 30 个实际 3DL 文件、6,041,562 个通道，全部整数码值完全一致；与规定量化参照的最大绝对误差、RMS、P99 均为 0，保留 `2e-12` 门槛。检查同时覆盖 10／12 位 header、行数／节点数、shaper、blue-fast 行序、Lustre `3DMESH`／`Mesh`／`LUT8`／`gamma 1.0`，并拒绝其他 flavor 偷带这些结构。

30 对 Debug／Release LUT 的 SHA-256 全部一致；两套输出均独立验证，字节一致不代替数学参照。

12 位格式固有量化与连续输入的最大差异为 `0.0001221001221001221`，每个文件的 `intrinsic_output_quantization_maximum` 单独记录；该差异不作为浮点误差，也不以此放宽整数逐码或 Double 门槛。本轮没有改进或更换计算公式，不声称一般场景精度提升。

## 编译、回归与发布边界

- 最终 Debug／Release 定向各八项，0 失败，退出 0。
- macOS、iOS generic、iOS Simulator 未签名 Release 三平台均 `BUILD SUCCEEDED`，退出 0。
- 150 个生产 Swift 源文件和三个实际 App 包审计通过，退出 0。静态检查不能独自证明全部内置资源均完成公式替代。
- 完整 Swift Release `--no-parallel` 执行 645 项、0 失败，退出 0；既有 `.labin`／NCP 两项可选外部夹具按设计跳过。各 bundle 计数见 `results.json`：LUTSharedUI 145、LUTProject 56、LUTPreview 91、LUTJobs 58、LUTFormats 56、LUTCore 183、LUTCatalog 24、LUTAnalysis 32。
- 发布证据检查退出 2：缺少真实 `docs/native-validation/full-scope-acceptance.json`。没有创建或伪造清单。

## 复现和结果包

工作目录 `/Users/lingru/claude/LUTCalc`；Xcode 27.0（27A266a）、Apple Swift 6.4、macOS 27.0 arm64、Python 3.14.6，三平台 SDK 为 27.0。构建复用此前三个独立 DerivedData 目录，对本轮源码重新编译。

实际命令、退出码、原始日志、工具链输出、真实 LUT／checkpoint／项目包、独立误差 JSON、源文件快照、App 文件身份和 SHA-256 清单见 [`artifacts/2026-10-03-batch-3dl-flavor/`](artifacts/2026-10-03-batch-3dl-flavor/)。

```sh
LUTCALC_BATCH_FLAVOR_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-3dl-flavor/debug-final" swift test --package-path Native/Packages/LUTKit --filter ExposureBatchThreeDLFlavorContractsTests
LUTCALC_BATCH_FLAVOR_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-3dl-flavor/release" swift test -c release --package-path Native/Packages/LUTKit --filter ExposureBatchThreeDLFlavorContractsTests
python3 tools/native-validation/verify-batch-3dl-flavor.py docs/native-validation/artifacts/2026-10-03-batch-3dl-flavor/release --output docs/native-validation/artifacts/2026-10-03-batch-3dl-flavor/independent-release.json
swift test -c release --package-path Native/Packages/LUTKit --no-parallel
```

重跑生成时使用新的证据目录，避免复用已存在的目标／checkpoint／项目包。

## 未覆盖范围

只接通已有三种 grammar，不证明厂商或目标调色软件对其解释一致。其他设备布局、任意输入／输出位宽、所有格式／参数／色彩计划组合和真实第三方往返仍未完成。inputShaper 资产的完整项目 schema 接入也不在本轮范围；NCP 写出仍 unsupported。

真实 File Provider 撤权／目标竞争／磁盘故障、实体 iPhone 11 后台恢复和 CPU／内存／流式写出／取消预算、iPad 模拟器计算基线、完整相机／旧算法／HDR/OOTF／ICC／LUTAnalyst，以及签名归档／公证／安装升级和逐项发布验收仍欠。UI 继续暂缓。
