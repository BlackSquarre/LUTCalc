# 2026-10-03 曝光批量格式与 inputShaper 后端验收

## 结论与范围

本轮修复 `ExposureBatchRequest` 重建逐曝光请求时遗漏 `inputShaper` 的实际缺陷，并把 shaper 内容和 domain 纳入批量恢复身份。当前八种导出格式的本地两曝光批量／检查点重开，以及 Flame `.3dl` 非线性 shaper 的完整 17³、33³、65³ 网格通过本轮契约和独立数值核对。

UI 按用户决定暂缓。H07/H08/H12/H14、FULL-06/FULL-08 和 Goal 继续保持 active；本轮没有创建 `full-scope-acceptance.json`，发布证据检查仍退出 2。

## 契约先行与缺陷

先新增 `ExposureBatchFormatContractsTests` 五项契约，再修改生产实现。第一次红灯因为逐节点重复失败诊断过多而主动中断（退出 130）；优化诊断后完整红灯退出 1，五项中出现 36 次失败（含 1 次 unexpected）。该调整仅在 shaper 已错误时跳过后续重复诊断，未减少成功路径的节点检查。

旧实现存在以下问题：

- 逐曝光请求丢失 base 的 `inputShaper`，使非线性 `.3dl` 变为均匀输入网格。
- 批量 fingerprint 忽略 input shaper；不同 shaper 可以被当作同一恢复请求。
- 非 `.3dl` 格式原应拒绝 input shaper，却因批量丢失该字段而静默写出。

修复在逐项请求中保留 `inputShaper`；有 shaper 时在既有 fingerprint 尾部加入长度分隔的算法身份、size、domain 和每个 RGB Double 的位模式。无 shaper 时沿用既有 fingerprint 字节构造。旧实现产生的 shaped checkpoint 不再匹配新请求，避免继续复用错误输出。

未改动生成 Double、网格、格式位宽、插值或 writer。合成曲线只在测试运行时生成，没有加入 App 资源。

## 已运行契约

| 契约 | 验证内容 |
| --- | --- |
| 快照与身份 | 逐项保留 shaper 和 sampler；样本／domain／有无 shaper 变化导致身份变化；同请求身份稳定；曝光被逐项替换 |
| 非线性 `.3dl` | 完整 17³/33³/65³，两个曝光，严格 parser 回读 header、全部节点与 12 位码值 |
| shaper 恢复拒绝 | 改变 shaper 后显式 report 和磁盘 checkpoint 均拒绝；原请求重新创建 store/coordinator 后恢复，已完成文件字节和 report 保留 |
| 八格式批量 | CUBE、SPI3D、SPI1D、3DL、ILUT、OLUT、Assimilate LUT、VLT，两曝光；第二文件故障后重开 checkpoint，保留第一文件并完成第二文件 |
| 非法组合 | 七种非 `.3dl` 格式携带 input shaper 均失败，后续项保持 pending，目录不产生输出 |

中断通过 exporter 在第二项抛出 `CancellationError` 注入；checkpoint 持久化后重新创建 actor/store。该证据不等于实际进程 SIGKILL、Task 取消延迟或 iPhone 后台终止恢复。

## 实际结果

| 检查 | 结果 |
| --- | --- |
| Debug 定向 | 5 项，0 失败，退出 0 |
| Release 定向 | 5 项，0 失败，退出 0 |
| 完整 Swift Release `--no-parallel` | 八个测试 bundle，共执行 634 项，0 失败；旧 `.labin`／NCP 两项可选外部夹具按既有设计跳过；退出 0 |
| macOS / iOS generic / iOS Simulator Release | 三平台未签名构建均 `BUILD SUCCEEDED`，退出 0 |
| 源码审计 | 150 个生产 Swift 文件通过，退出 0 |
| 实际三个 App 包审计 | 禁止资源和直接链接检查通过，退出 0 |
| 发布证据检查 | 缺少真实 `full-scope-acceptance.json`，退出 2 |

独立脚本 [`verify-batch-format-shaper.py`](../../tools/native-validation/verify-batch-format-shaper.py) 使用 Python 标准库 `Fraction` 从有理数公式产生参照，直接重读原始文本，不调用生产 Swift 或旧 JavaScript。整数格式先逐码要求完全一致，再比较归一化值；CUBE/SPI 文本误差门槛仍为 `2e-12`。

Debug 与 Release 各核对 24 个实际文件、2,193,840 个通道，最大绝对误差均为 `1.0068426197458456e-16`。每个文件的节点数、通道数、SHA-256、最大误差、RMS、P99 见独立 JSON；24 对 Debug/Release LUT 文件的 SHA-256 全部一致。

## 复现与证据

工作目录为 `/Users/lingru/claude/LUTCalc`。工具链为 Xcode 27.0（27A266a）、Apple Swift 6.4、macOS 27.0 arm64、Python 3.14.6；三平台 SDK 均为 27.0。逐命令原文、退出码、工具链输出、红灯／绿灯／完整回归／构建／审计日志、实际 LUT 与检查点和哈希清单保存在 [`artifacts/2026-10-03-batch-format-shaper/`](artifacts/2026-10-03-batch-format-shaper/)。

主要复现命令：

```sh
LUTCALC_BATCH_FORMAT_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-format-shaper/debug" swift test --package-path Native/Packages/LUTKit --filter ExposureBatchFormatContractsTests
LUTCALC_BATCH_FORMAT_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-format-shaper/release" swift test -c release --package-path Native/Packages/LUTKit --filter ExposureBatchFormatContractsTests
python3 tools/native-validation/verify-batch-format-shaper.py docs/native-validation/artifacts/2026-10-03-batch-format-shaper/release --output docs/native-validation/artifacts/2026-10-03-batch-format-shaper/independent-release.json
swift test -c release --package-path Native/Packages/LUTKit --no-parallel
```

再次生成应使用新的证据目录，避免复用已存在的输出文件和 checkpoint。

## 未覆盖范围

- 八格式只证明当前枚举的本地默认参数、单位 domain、线性 Rec.2020 场景输入和两个曝光；没有证明所有参数／色彩计划／设备布局组合。非线性 shaper 仅验证 Flame `.3dl` 17/33/65。
- Lustre／Kodak flavor 等导出选项在批量中的完整快照、身份和项目持久化仍须单独核对；input shaper 资产的项目 schema 和完整交互接入不在本次范围。
- NCP 写出仍明确 unsupported；没有厂商规格和真实 Nikon 往返证据前不得猜实现。
- 没有新增 Finder／Files／目标调色软件界面往返、iCloud／File Provider 撤权或替换竞争、磁盘故障矩阵、实际进程终止、实体 iPhone 11／iPad 性能证据。
- App 静态扫描只能证明所列禁止文件／框架边界，不能独自证明全部内置资源均有可追溯算法；完整算法台账、相机、ICC、HDR/OOTF、LUTAnalyst、签名和发布逐项验收仍欠。
