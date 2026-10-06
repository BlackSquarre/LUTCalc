# Conventional Gamma 与参数化 Gamma 计划身份验收

## 范围

修复 Conventional Gamma 与 Parameterized Gamma 的 `TransformPlan.planVersion` 身份遗漏。`planVersion` 被预览请求身份检查和曝光批次指纹使用，因此数值行为不同的计划不能共享该身份。本项不改 transfer 公式、数值路径或采样参数。

## 契约与实现

- Conventional Gamma 旧身份记录 transfer，但没有记录输入／输出色彩空间。新增契约比较仅改变输入或输出色彩空间的 gamma22 计划，旧实现下 2 个身份断言失败。
- Conventional Gamma 现使用 `legacy-conventional-gamma-v2:<inputTransferID>:<outputTransferID>:inSpace:<inputColorSpaceID>:outSpace:<outputColorSpaceID>`；既有同侧 gamma22／gamma24、正反方向和输出代码单位后缀保持不变。
- Parameterized Gamma 旧身份不含输入／输出色彩空间。新增契约比较仅改变输入或输出色彩空间的相同参数计划，旧实现下 2 个身份断言失败；既有参数 bit pattern、方向及 encodedCut 规范化契约保持不变。
- 新参数化身份记录 input/output `TransferID`，并分别按 exponent、linearSlope、offset、linearCut、effective encodedCut 的 IEEE-754 `Double.bitPattern` 16 位十六进制编码。此表示无损且无歧义，不经过低精度十进制格式化。省略 `encodedCut` 时按算法实际采用的 `linearSlope * linearCut` 规范化，因此与相同有效切点的显式值使用同一身份。

## 验证

- 工具链：Xcode 27.0（27A266a），Swift 6.4.0.34.1。
- 先行红测：`swift test --package-path Native/Packages/LUTKit -c release --filter 'ConventionalGammaContractsTests/testConventionalGammaPlanIdentityIncludesBothColorSpaces|ParameterizedGammaContractsTests/testParameterizedGammaPlanIdentityIncludesBothColorSpaces'`，4 个身份断言失败，符合修复前预期。
- 修复后：`swift test --package-path Native/Packages/LUTKit -c release --filter 'ConventionalGammaContractsTests|ParameterizedGammaContractsTests'`，18 项通过、0 失败。覆盖 12 个 Conventional Gamma 同 transfer identity、gamma22/gamma24 正反方向、两端色彩空间及输出行为；参数精确身份、两端色彩空间、方向和隐式/等价显式 encodedCut。
- 本包为计划身份检查，不以数值误差作正确性声明；新增输出比较只证明不同参数的计划产生不同值，transfer 数值准确度由已有独立参照契约负责。未运行全量 SwiftPM、三平台构建或设备验收。

## 未覆盖范围

本次只关闭两个 Gamma 分支的 `planVersion` 参数/方向别名。其他 transfer 家族的计划身份仍需审计；该记录不代表完整算法、平台、发布验收或迁移目标完成。
