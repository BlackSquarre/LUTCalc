# ICC 任意通道 profile linking 数学子集验收

日期：2026-10-05

## 范围

本阶段在现有 `ICCMPETransform` 数组执行能力之上，闭合用户导入 ICC `mpet` profile 成对 linking 的任意设备通道子集。source 使用当前 rendering intent 对应的 `D2B0`...`D2B3`，target 使用对应的 `B2D0`...`B2D3`；PCS 必须两侧一致且为 `XYZ ` 或 `Lab `。设备端通道数由各自 profile color-space signature 声明，可在 1...15 范围内不同；PCS 始终为三通道。

新增 `ICCRGBProfileLink.convert(_ device: [Double])` 只服务 MPE route，并公开 source/target 设备通道数。旧 `convert(_ encodedRGB: RGB64)` 对非三通道 MPE 明确拒绝；matrix/TRC、传统 LUT 和传统 Lab route 继续保持 RGB-only，generic 数组调用这些路径明确拒绝。没有把传统 `mft`/`mAB`/`mBA` 任意通道或其他 MPE 元素扩展进本阶段。

## 规范与工具链

- 规范：ICC.1:2022-05 §6.3.4、§10.16；来源 `/tmp/icc-1-2022-05.pdf`，SHA-256 `aad8e33128635893e38ae780def3b29e661e4541be03cb235c67dd94d558001b`。
- 工具链：Apple Swift 6.4、Xcode 27.0、macOS arm64；独立参照为 Python 3 `Decimal(90)`。
- 实现：[ICCRGBProfileLink.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Sources/LUTPreview/ICCRGBProfileLink.swift)
- 契约：[ICCRGBProfileLinkContractsTests.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCRGBProfileLinkContractsTests.swift)
- 参照：[probe-icc-profile-linking.py](/Users/lingru/claude/LUTCalc/tools/native-validation/probe-icc-profile-linking.py)

## 契约与结果

契约覆盖：

- XYZ PCS 的 3→4 MPE linking；
- Lab PCS 的 4→3 MPE linking；
- 四种 rendering intent 的 MPE tag 成对分派；
- source/target 设备通道数不同；
- 非 MPE CMYK 仍拒绝传统 RGB-only 路径；
- RGB 便利入口和传统 route 的显式拒绝；
- PCS 不一致、MPE pair 不完整和既有 RGB 回归。

定向 Debug：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter ICCRGBProfileLinkContractsTests
```

30 项通过，0 失败。结果包 SHA-256：`a9f93232680da573dc51f9806fa287b9cfa2d75158c843fe431b8085496ce807`。

定向 Release：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ICCRGBProfileLinkContractsTests
```

30 项通过，0 失败。结果包 SHA-256：`bd4d9694083c5dee4f7359ff51e59a323c80cc75182c61544557e8e3e943614e`。

当前源码的 Swift Release 全量测试也通过：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

八个测试包均通过，0 失败；`LUTFormats` 保留 2 个既有可选外部夹具跳过。结果包 SHA-256：`0d7f209c06e1bf017866fc7b32908e40144f1e1285420215bb42175f877c57a1`。

独立参照：

```sh
python3 tools/native-validation/probe-icc-profile-linking.py
python3 -m py_compile tools/native-validation/probe-icc-profile-linking.py
```

`Decimal(90)` 结果文件 SHA-256：`b6d1b53de5590e28e897cb6203a3bb4f429c3785b4ed51a84528a7d81cd8d268`。XYZ 3→4 结果为 `[0.2, 0.3, 0.4, 0.500]`；Lab 4→3 的 PCS 浮点值为 `[50.00, -26.00, 25.00]`，目标设备结果为 `[0.5, 0.4, 0.6]`。MPE 参数按 float32 编码后由 Swift 解码为 `Double`，契约误差均低于 `2e-7`；参照只验证矩阵链和 PCS 语义，不把 synthetic profile 当作真实厂商 profile 证据。

源码 SHA-256：`b971c834cb6826a0300ceb4c42f46d22d52ad07a7e95e2581ecf2a138b3e4c5b`。

所有结果包位于 `docs/native-validation/artifacts/2026-10-05-icc-profile-linking/`。

## 未覆盖范围

本阶段不关闭：传统 `mft1/mft2/mAB/mBA` 任意通道 linking；其他未来 MPE 元素；真实非 synthetic profile 逐码独立参照；所有 profile class 和通道组合；black point compensation；gamut mapping；ColorSync；HDR/EDR；目标调色软件往返；项目 schema、图像显示和 UI；`.labin` `0/9`、直接查表注册 `0/45`；LUTAnalyst 全局 3D 反求；完整发布清单。Goal 保持 `active`。
