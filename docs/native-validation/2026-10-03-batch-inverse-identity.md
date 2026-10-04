# 2026-10-03 输入反求计划的批量恢复身份验收

## 结论

本轮修复后端实际缺陷：`ExposureBatchRequest` 此前只把输入反求的插值名写入 fingerprint，未绑定用于求值的 transfer 样本和 domain。后端直接 API 或有效 transfer 与外层 postLUT 不同的请求，可能把不同反求曲线视为同一批次，误用已完成文件。

现已在 `ImportedLUTInversePlan` 构造严格单值 cubic 计划时冻结内容 SHA-256，并纳入批量 fingerprint；不同样本、domain、size 的显式 report／durable checkpoint 恢复被拒绝。无反求请求沿用此前身份构造。旧的有反求 checkpoint 因缺少内容绑定不再接受，已发布文件不会因此删除。

本轮只验收输入反求内容身份和本地恢复安全，不改变求逆算法、Double、网格、位宽、插值或误差门槛。UI 继续暂缓，完整迁移和 Goal 保持 active。

## 契约先行

先新增 `ExposureBatchInverseIdentityContractsTests` 三项行为契约，运行旧生产实现，退出 1：3 项、7 次失败、0 unexpected。其中不同曲线成功接用了旧 report，产生了本应拒绝的第二文件；后续检查点操作也未按契约报 `.checkpointMismatch`。

随后实现修复，Debug 定向 3/3 通过；加入用于独立哈希核对的诊断文件后，在新目录复跑 Debug 3/3 通过。Release 定向 3/3 通过。原始红灯和两次 Debug 日志均保留。

契约覆盖：

- 同插值名下逐通道样本变化、节点数变化、六个 domain 分量变化必须改变批量身份；相同数值和改变 title 保持身份。
- `analysisFile.transferLUT` 被选择时绑定有效 transfer；即使 outer/post LUT 相同，不同有效 transfer 仍不同。相同有效 transfer 的直接／analysis 路由保持一致。
- 第一个实际 CUBE 提交、第二项故障注入后，变化的 inverse 不得复用 report 或重新打开的磁盘 checkpoint；原 inverse 可用新 coordinator/store 恢复，首文件字节和已完成 report 保留。完整两个 17³ 文件逐节点检查。

这里的中断为第二项 exporter 抛出 `CancellationError`，不作为操作系统进程终止或真机后台恢复证据。

## 内容身份契约

SHA-256 输入按以下冻结顺序构建：

1. UTF-8 `native.input-transfer-inverse-content.v1`，末尾 NUL。
2. 实际插值 rawValue，末尾 NUL。
3. 节点数，UInt64 little-endian。
4. domain min RGB、max RGB 的六个 Double 位模式，little-endian。
5. 实际 transfer 全部节点的 RGB Double 位模式，little-endian。

验证仍拒绝非 1D、shaper、非严格单值、非支持插值输入。身份在成功构造后一次计算，只额外保存哈希字符串，不为身份再保留一份 transfer 采样数组。title、来源文字及未参加求值的颜色部分不写入数值身份。该身份不是数字签名，不代表任意三维逆或完整 LUTAnalyst。

## 独立参照

独立脚本 [`verify-batch-inverse-identity.py`](../../tools/native-validation/verify-batch-inverse-identity.py) 使用 Python 标准库 `Fraction`、`struct` 和 `hashlib`。参照为合成严格单值 `f(x)=2x`，反函数为 `x/2`；脚本独立构造 17 点和 binary contract，再重读全部实际 CUBE 文本，不调用 Swift 或旧 JavaScript。

Debug／Release 各两个 17³ CUBE，共 29,478 个通道，最大绝对误差、RMS 和 P99 均为 0；门槛保持 `2e-12`。该结果验证本例内容绑定不改变生成结果，不声称改进一般 cubic 求逆的精度。有效 transfer 哈希均等于独立参照：

```text
b4acbd278406362c526204c7378eed9ae196aa3f56dcae628db70ecde127c6f3
```

## 编译、回归与发布边界

- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出 0，`BUILD SUCCEEDED`。
- 150 个生产 Swift 文件审计和实际三个 App 包审计均退出 0；禁止资源／直接框架链接检查通过。静态扫描不能独自证明所有旧内置资源均完成算法替代。
- 完整 Swift Release `--no-parallel` 实际执行 637 项，0 失败，退出 0；既有 `.labin`／NCP 两项可选外部夹具按设计跳过。八个 bundle 的逐项计数见 `results.json`：LUTSharedUI 137、LUTProject 56、LUTPreview 91、LUTJobs 58、LUTFormats 56、LUTCore 183、LUTCatalog 24、LUTAnalysis 32。
- `check-release-evidence.py` 仍退出 2，原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。没有创建或伪造该清单，没有将 H/FULL 或 Goal 标记全量完成。

## 复现与结果包

工作目录 `/Users/lingru/claude/LUTCalc`。本轮实际工具链输出、完整命令和退出码、测试／构建／审计日志、两个构建的实际输出和 checkpoint、独立参照 JSON、App 文件哈希和源文件快照见 [`artifacts/2026-10-03-batch-inverse-identity/`](artifacts/2026-10-03-batch-inverse-identity/)。Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Python 3.14.6；三平台 SDK 为 27.0。构建复用此前三个独立 DerivedData 目录，均对本轮修改后的源码重新构建。

```sh
LUTCALC_BATCH_INVERSE_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-inverse-identity/debug-final" swift test --package-path Native/Packages/LUTKit --filter ExposureBatchInverseIdentityContractsTests
LUTCALC_BATCH_INVERSE_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-03-batch-inverse-identity/release" swift test -c release --package-path Native/Packages/LUTKit --filter ExposureBatchInverseIdentityContractsTests
python3 tools/native-validation/verify-batch-inverse-identity.py docs/native-validation/artifacts/2026-10-03-batch-inverse-identity/release --output docs/native-validation/artifacts/2026-10-03-batch-inverse-identity/independent-release.json
swift test -c release --package-path Native/Packages/LUTKit --no-parallel
```

再次生成应改用新的证据目录，避免复用输出和 checkpoint。

## 未覆盖范围

一般病态 cubic 的精度、完整 TF／颜色分离和重建、量化／方向元数据、任意 3D 逆仍以原有范围验收，本轮身份修复不能替代这些证据。3DL flavor 的批量参数快照／持久化和完整设备格式矩阵仍未接入；NCP 写出仍 unsupported。

真实 File Provider 授权／目标竞争／故障矩阵、实际 iPhone 11 后台终止恢复和性能、iPad 模拟器计算预算、相机／HDR／ICC 完整覆盖、签名归档／公证／安装升级与逐项发布验收仍未完成。本轮没有设备或 UI 操作。
