# ICC 传统任意通道 profile linking 数学子集验收

日期：2026-10-05

## 范围

本阶段闭合用户主动导入的传统 ICC `mft2`、`mAB`、`mBA` 任意设备通道数组路径。source 使用 `A2B1`／`A2B0`，target 使用 `B2A1`／`B2A0`；设备通道数由 profile 的 color-space signature 声明，可在 1...15 范围内不同。PCS 为三通道 `XYZ ` 或 `Lab `，执行结果使用 Swift `Double`。

`mft1` 的任意设备转换保留为通用数组执行器；但 `mft1` 与 `XYZ ` PCS 的 linking 明确拒绝，因为 ICC 没有定义 8 位 PCSXYZ 编码。传统矩阵仍固定为 3×3（`mft`）或 3×4（`mAB/mBA`），非 PCS 设备维度不扩展矩阵；任意设备差异由 1D 曲线和 N 维 CLUT 表达。没有打包 profile、厂商 LUT、旧 `.labin` 或等价采样表。

## 依据和实现

- 规范：ICC.1:2022-05 §10.10、§10.11、§10.12、§10.13；本机下载的规范文件为 `/tmp/icc-2022.pdf`。
- `mft` CLUT 采用 ICC 定义的首通道最慢、末通道最快轴序；`mAB/mBA` CLUT 使用每个输入维度的网格声明和相同轴序。
- `ICCMFTTransform` 新增 `[Double]` 执行入口，支持 1...15 输入/输出通道；RGB 入口只作为三通道包装。
- `ICCMABTransform` 新增 `[Double]` 执行入口，A/B 曲线数量和 CLUT 维度随方向和 profile 通道数变化；固定矩阵仍只在合法三通道 PCS 边界执行。
- `ICCMFTXYZTransform`、`ICCMABXYZTransform`、`ICCMFTLabTransform`、`ICCMABLabTransform` 增加任意设备到 PCS 及 PCS 到设备的数组适配。
- `ICCRGBProfileLink` 新增传统 XYZ/Lab 任意通道相对色度路由；RGB matrix/TRC、RGB LUT、MPE 和既有 Lab absolute 路径保持原边界。

## 契约先行

契约覆盖：

- 4 通道 CMYK→3 通道 PCS 的 `mft2` 4D CLUT；
- 3 通道 PCS→4 通道 CMYK 的 `mft2` 3D CLUT；
- `mAB`／`mBA` 同样的 4→3 与 3→4 路径；
- Lab PCS 的传统任意通道 linking；
- 3×3／3×4 矩阵边界、非恒等非 PCS 矩阵拒绝、输入维度和 RGB 便利入口拒绝；
- 既有 3 通道 mft、mAB/mBA、relative intent precedence 和旧 RGB route 回归。

定向 Debug 命令：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter 'ICCMFTContractsTests|ICCMABContractsTests|ICCRGBProfileLinkContractsTests'
```

结果：`ICCMFTContractsTests` 11 项、`ICCMABContractsTests` 18 项、`ICCRGBProfileLinkContractsTests` 33 项，合计 62 项执行，0 失败。

定向 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCMFTContractsTests|ICCMABContractsTests|ICCRGBProfileLinkContractsTests'

结果：`ICCMFTContractsTests`、`ICCMABContractsTests` 和
`ICCRGBProfileLinkContractsTests` 合计 62 项执行，0 失败，退出码 `0`。

完整 Swift Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

结果：8 个测试包共 869 项执行，0 失败；`LUTFormats` 的 2 项既有外部夹具按原规则跳过。
完整日志为
`docs/native-validation/artifacts/2026-10-05-icc-traditional-arbitrary/full-release.log`，
SHA-256：`fee79c0ada8550c74066a0d86f261cd2dec7e110018cec3a5ad15944f3d6e241`。

原生数值与静态门禁：

```sh
Scripts/verify-native-numerics.sh
```

退出码 `0`。日志为
`docs/native-validation/artifacts/2026-10-05-icc-traditional-arbitrary/numerics-gate.log`，
SHA-256：`c12d0849a38f854ab1634a718a6222afeb3ad76bc9013a3a4c8d3baf15831032`。
```

## 独立参照

```sh
python3 -m py_compile tools/native-validation/probe-icc-traditional-arbitrary.py
python3 tools/native-validation/probe-icc-traditional-arbitrary.py
```

参照使用 Python `Decimal(90)`，不导入待测 Swift 或 profile payload。CMYK 输入 `[0.2, 0.4, 0.6, 0.8]` 经 4→3→4 参照得到 PCS `[0.2, 0.4, 0.6]` 和目标 `[0.2, 0.4, 0.6, 0]`。结果文件为 `docs/native-validation/artifacts/2026-10-05-icc-traditional-arbitrary/decimal-reference.json`，SHA-256：`a139400c65f253142eef6b0ff14bf25909939d5cb37dbe082dab6d241b5f72a9`。

## 未覆盖范围

本阶段只关闭传统 LUT profile linking 的任意设备通道相对色度数学子集。真实第三方 profile 逐码参照、所有 profile class 和 rendering intent、传统 `mft1` 的 Lab 真实夹具、black point compensation、gamut mapping、ColorSync、其他 ICC 类型和 MPE 元素、HDR/EDR、目标调色软件往返、项目 schema、图像显示、UI、`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 全局 3D 反求和 Goal 仍未完成。未创建或修改 `docs/native-validation/full-scope-acceptance.json`。
