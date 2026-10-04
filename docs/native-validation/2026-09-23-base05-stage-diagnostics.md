# BASE-05 固定种子阶段诊断

日期：2026-09-23。接续[比较器统计与故障注入](2026-09-23-base05-comparator.md)，本步为旧引擎无调节 D-Log2/D-Gamut2、Data→Data、曝光 +1 链新增 32 个固定种子诊断节点。在同一节点比较解码、色域/曝光后的线性值和最终编码值；仅用于定位差异，不将旧引擎认作独立公式真值。UI 没有修改。

## 契约与来源

先以 `--stage-fixture` 调用旧引擎夹具生成器，得到退出码 1，确认此前没有阶段输出。新增选项后，生成器仍运行真正的 `LUTGamma.inCalcRGB → LUTColourSpace.calc(g=true) → LUTGamma.outCalcRGB`，在会被后续旧方法就地修改的缓冲区上先拷贝阶段数据。样本包含端点、中点，以及种子 `0x5eed2026`、LCG32 常数 `1664525/1013904223` 产生的固定节点，共 32 个；按 R 最快网格索引升序写入测试 JSON。

旧引擎内部线性采用 0.2 标度，Swift 计划阶段采用场景 0.18 标度，因此旧解码和色域/曝光阶段乘明确的 `0.9` 后，分别对照 Swift `StageTrace` 的阶段 2 与 10；最终编码直接对照阶段 19。来源校验器核对六份旧源码哈希、固定种子节点、阶段向量有限性，并以位精确 Double 值核对阶段最终输出与原 17³ Float64 全网格夹具。Swift 对每阶段/通道保留 `2e-12` 尺度化门槛，没有改变现有接受标准。

修改文件：`generate-legacy-dlog2-exposure.js`、`verify-legacy-dlog2-exposure.js`、`Native/Packages/LUTKit/Sources/LUTContractChecks/main.swift`、`verify-native-subset.sh`；新增 `tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json`。该 JSON 和旧引擎只在研发测试路径，未进入 App。重新生成原 17³ Data→Data `.f64`/元数据后的哈希与既有记录完全相同，没有改变原夹具。

## 实际命令与结果

```text
node tools/native-validation/generate-legacy-dlog2-exposure.js --size 17 --stage-fixture tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json
node tools/native-validation/verify-legacy-dlog2-exposure.js --metadata tests/fixtures/native-contracts/legacy-dlog2-exposure17.json --binary tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64 --stages tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json
swift build -c release --package-path Native/Packages/LUTKit
Native/Packages/LUTKit/.build/release/LUTContractChecks tests/fixtures/native-contracts/numeric-contracts.json tests/fixtures/dlog2-reference.json tests/fixtures/native-contracts/parser-contracts.json tests/fixtures/native-contracts/first-chain-reference.json tests/fixtures/native-contracts/srgb-reference.json tests/fixtures/native-contracts/srgb-legacy-reference.json tests/fixtures/native-contracts/srgb-plan-reference.json tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64 tests/fixtures/native-contracts/legacy-dlog2-exposure17-stages.json
tools/native-validation/verify-native-subset.sh
```

以上命令最终均实际退出码 0。首次修改子集入口时，macOS 系统 Bash 3.2 在 `set -u` 下对空数组展开报 `stage_arguments[@]: unbound variable`，入口退出码 1；已改为显式分支与函数传参，再运行退出码 0。此失败属于验证脚本兼容性，未改数值门槛。旧 JS 测试仍 9/9，静态扫描 35 个 Swift 源文件。

| 阶段 | 对照单位 | 32 节点最大尺度化误差 | 门槛 |
| --- | --- | ---: | ---: |
| 解码，Swift 阶段 2 | 场景 0.18 线性 | `1.2267515946243955e-16` | `2e-12` |
| 色域与曝光后，Swift 阶段 10 | 场景 0.18 线性 | `5.897504842334103e-14` | `2e-12` |
| 最终编码，Swift 阶段 19 | Data 归一化信号 | `1.746242039857293e-13` | `2e-12` |

SHA-256：阶段 JSON `e39c890a3f67c526096a725018425cfdbc9290de8835eb57719a663e595c15c7`；生成器 `6da25c6a108463749328def67b1c5d46b5f7929e91181c8dbad554b5fd6fa350`；来源校验器 `4856dfc8ceaf0433952b53d107f8287900a74b59832571fabd031564bd958b6b`；Swift 契约入口 `079264611d1486233710a6781edbad0cfbcd171ef4105cc92d16013fce4cd723`；子集入口 `77fae8e4901bcacafa92d1593f1f4ebbc2fae51735d1e45f2887e039589e12fd`。原 Float64 二进制哈希 `30eb1ec24358e804a633849d5b836be8b1c7c13025c646ea9fa2597e552c78b2`，元数据 `f422b6536660673464555524b879e07277be3e2a252ff5517426c8500cc34a3b`。

## 剩余范围

阶段诊断只覆盖一条 17³ Data→Data 无调节链；其他范围、1D、调节、限制与所有旧预设仍缺完整旧路径阶段参照。BASE-03/05 和 H06 仍只部分完成。当前机器没有完整 Xcode/iOS SDK，XCTest、两端 `.app`、模拟器、真机和发布验收均未由本步通过。
