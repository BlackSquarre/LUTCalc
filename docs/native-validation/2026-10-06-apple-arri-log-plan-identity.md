# Apple Log、Apple Log 2 与 ARRI LogC4 计划身份验收

## 范围

修正 `TransformPlan.basePlanVersion` 中 Apple Log、Apple Log 2 与 ARRI LogC4 的固定版本身份，使其保留 input/output `TransferID` 和 input/output `ColorSpaceID`。本项只涉及计划缓存与任务指纹身份，不修改 transfer 公式、色彩矩阵、Double 数值路径或生成精度。

现有目录登记给出的适用色域分别为 Apple Log → Rec.2020、Apple Log 2 → Apple Wide Gamut、ARRI LogC4 → ARRI Wide Gamut 4；对应目录来源记录了 Apple/ARRI 公开 primaries 与 AP0 转换参照。本次身份字符串纳入实际设置的两端色域，不假定只有这些预设组合。

## 契约与实现

新增 `AppleARRILogPlanIdentityContractsTests`，逐个覆盖三个 transfer 的 decode/encode 方向、输入色域变体、输出色域变体，以及身份中保留 transfer 与 AP0 两端 ID。`TransformPlan.swift` 三个分支现按 `minimal-<family>-v1:<inputTransferID>:<outputTransferID>:inSpace:<inputColorSpaceID>:outSpace:<outputColorSpaceID>` 生成身份。

## 验收状态

- 首次定向构建被并行新增的 Mi-Log／L-Log／KineLOG3 契约缺少 `exposureStops` 阻塞；Apple/ARRI 契约未取得独立修复前红测，不将该次编译失败记为红测证据。
- 参数补齐后，由主线统一运行组合命令 `swift test --package-path Native/Packages/LUTKit -c release --filter 'Rec709Rec2020PQPlanIdentityContractsTests|FLog2ContractsTests|ILogContractsTests|VLogPlanIdentityContractsTests|MiLogContractsTests|LLogContractsTests|KineLog3ContractsTests|AppleARRILogPlanIdentityContractsTests|SRGBPlanIdentityContractsTests|ConventionalGammaContractsTests|ParameterizedGammaContractsTests|TransformAlgorithmWiringContractsTests'`。`LUTCoreTests` 执行 59 项、0 失败，整条命令退出码 `0`。
- 整包 `swift test --package-path Native/Packages/LUTKit -c release` 退出码 `0`；`git diff --check` 通过。
- 数值误差不适用：本改动不触碰数值计算。

## 未覆盖范围

本记录不证明全局 `planVersion` 身份审计完成，也不关闭 `.labin`／直接查表替代、完整 ICC、HDR/OOTF、平台运行、签名发布或全量验收清单。Goal 继续保持 `active`。
