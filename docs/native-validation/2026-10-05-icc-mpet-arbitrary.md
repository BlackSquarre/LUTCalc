# ICC mpet 任意设备通道数学子集验收

日期：2026-10-05

## 范围

本阶段闭合用户导入 ICC `multiProcessElementsType` 的任意设备通道执行子集。PCS 仍是 ICC 规定的三通道 `XYZ ` 或 `Lab `；设备端依据 profile color-space signature 的通道数，可使用 `CMYK` 或 `3CLR`...`FCLR` 等最多 15 通道。支持 `cvst` 公式曲线、`matf` 任意输入／输出矩阵、`clut` 任意输入／输出维度、`bACS`／`eACS` pass-through，以及元素之间严格的通道衔接。保留 MPE 元素不裁切、CLUT 输入只按规范裁切到 `0...1`、float32 参数有限性和共享区间校验。

这是 `ICCMPETransform` 的直接数组执行能力，不把 `ICCRGBProfileLink` 改名或扩展成通用 profile linker；现有 profile linking 仍只接受 RGB source/target。没有加入内置 profile、LUT、`.labin` 或 UI 字段。

## 规范与工具链

- 规范：ICC.1:2022-05 §10.16.2.1–§10.16.2.4，Table 62/63；来源 `/tmp/icc-1-2022-05.pdf`，SHA-256 `aad8e33128635893e38ae780def3b29e661e4541be03cb235c67dd94d558001b`。
- 工具链：Apple Swift 6.4、Xcode 27.0、macOS arm64；独立参照为 Python 3 `Decimal(90)`。
- 实现：[ICCMPETransform.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Sources/LUTPreview/ICCMPETransform.swift)
- 契约：[ICCMPEContractsTests.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMPEContractsTests.swift)
- 参照：[probe-icc-mpet-arbitrary.py](/Users/lingru/claude/LUTCalc/tools/native-validation/probe-icc-mpet-arbitrary.py)

## 契约与结果

先加入 4 通道 CMYK 的 D2B/B2D 矩阵、曲线串接、CLUT 首通道最快和非法维度契约；旧实现按预期因缺少通用数组 API 编译失败。实现后定向 Debug／Release 共 22 项通过，覆盖原有 RGB 回归、Lab／XYZ PCS、公式曲线、`samf` 中间段、ACS、非法浮点和共享区间。

```sh
swift test --package-path Native/Packages/LUTKit --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
python3 tools/native-validation/probe-icc-mpet-arbitrary.py
python3 -m py_compile tools/native-validation/probe-icc-mpet-arbitrary.py
swift test --package-path Native/Packages/LUTKit -c release
```

定向 Release 结果包为 `artifacts/2026-10-05-icc-mpet-arbitrary/targeted-release.log`，退出码 `0`，SHA-256 `41034ac15de7b2f36eeb472951be42f639ca8c939a6bb9369661f8f8a38c2570`。全量 Swift Release 结果包为 `full-release.log`，退出码 `0`，SHA-256 `b37f53175dea4d90503783287cc2291072a7fb1cc2bd93a8523347d11d92f73a`；七个测试包共执行 784 项、0 失败，另有 2 项既有可选夹具按原规则跳过。

独立参照结果为 `decimal-reference.json`，SHA-256 `2a1c0fc626c369f461a8d39610865abf53d0a044259de2fcce3aee0363fcf4dd`。4 通道矩阵结果为 `[3.0, 0.7, 0.05]`，4D CLUT 结果为 `[0.25, 0.5, 0.75]`，B2D 结果为 `[0.1, 0.2, 0.3, 0.6]`；Swift 与 Decimal 参照在 Double 表示范围内一致。实现源码 SHA-256：`d792074461e095fd846b54611b49139a595ec0bac25196de0030b5a0ee647399`；契约 SHA-256：`b3164dc1a7fadcf1f7f7e9fa804392cc1f3742d359db51d8d6798f93a9be7f9a`。

`Scripts/verify-native-numerics.sh` 退出码 `0`，结果包为 `native-numerics.log`，SHA-256 `d3643d7490f940e0c097799659df2f2d404b2fd72e8f249a1611ed2689663df8`；54 个 CUBE 生成／读回和原生静态、命令行契约均通过。该门禁只说明既有数值子集未回归，不扩大本阶段的 ICC 范围。

## 未覆盖范围

本阶段不关闭 RGB profile linking 以外的任意通道成对路由、传统 `mft`／`mAB`／`mBA` 任意通道、真实厂商 profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR、目标软件往返或发布清单。ICC.1:2022-05 当前定义的 MPE 元素集合已覆盖；未来新增且未知的元素仍按规范拒绝并回退，不能在没有新规范时猜测实现。`parf` 只接受 type 0、1、2，传统 `para` 的 type 3、4 不属于 `cvst`。当前语义拒绝 `samf` 首段；末段在有前一段隐含起点时允许，详见 2026-10-06 末段采样验收。`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 全局 3D 反求和 Goal 仍保持未完成。
