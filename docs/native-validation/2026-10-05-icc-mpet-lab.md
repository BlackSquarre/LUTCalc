# ICC MPE PCSLAB 子集验收

日期：2026-10-05

## 范围

本阶段只处理已有 ICC 用户导入 CPU 范围中的 `D2B0`/`B2D0`、`D2B1`/`B2D1`、`D2B2`/`B2D2`、`D2B3`/`B2D3` 三通道 `mpet`，并补齐 profile PCS 为 `Lab ` 的分派。依据为 ICC.1:2022-05 §6.3.4.1、§6.3.4.2、§9.2.9–§9.2.12、§9.2.25–§9.2.28 和 §10.16。

float32 PCS Lab 的三个值直接表示 `L*`（0...100）、`a*`、`b*`。它和 `mft1/mft2/mAB/mBA` 的 unsigned normalized PCS Lab 不是同一种编码。本实现把 `L*` 转换为现有 `CIELABColor` 的 0...1 存储，返回到 MPE 时再乘回 100；不做 8/16 位量化和 PCS 隐式裁切。

## 契约先行

实现前新增的契约调用 `deviceRGBToPCSLab`、`pcsLabToDeviceRGB`，旧实现因缺少 API 编译失败，红灯日志为（SHA-256：`a0fd10638ee702111eb756243e8be4d69b4d8dae3fccfa16a84bef1e00ac0e17`）：

```text
/tmp/lutcalc-mpet-lab-red.log
error: value of type 'ICCMPETransform' has no member 'deviceRGBToPCSLab'
error: value of type 'ICCMPETransform' has no member 'pcsLabToDeviceRGB'
```

实现后契约覆盖：

- D2B 的 `100/255/-128` 矩阵把输入转换为直接 float32 `L*`/`a*`/`b*`；
- B2D 的逆比例与偏置回到设备值；
- Lab PCS 的 absolute `D2B3`/`B2D3` linking；
- 原有 XYZ MPE 四种 intent 路由保持不变。

## 执行结果

工具链：macOS 26、Apple Swift/Xcode 工具链、Swift Package XCTest、Python 3 `Decimal(90)`。

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter 'ICCMPEContractsTests|ICCRGBProfileLinkContractsTests'
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ICCMPEContractsTests|ICCRGBProfileLinkContractsTests'
python3 tools/native-validation/probe-icc-mpet-lab.py
python3 -m py_compile tools/native-validation/probe-icc-mpet-lab.py
```

Debug 与 Release 均为 40 项执行、0 失败。Debug 日志 SHA-256：`4ec3d607b7199f92b6d16c41014611deb52c39281e04eaec469b835ec5aa0010`；Release 日志 SHA-256：`725c8294e230c3e4de97a58358316403a447638968f0890171ec6e4ad25b9e64`。

完整 `swift test -c release` 八个测试包共执行 837 项，2 项既有可选夹具按原测试设计跳过，0 失败。日志 SHA-256：`d21c573b1d8c7b00542aed0ac5695576b84a0a4e5acde4f8dc48fb6f2c515fb4`。

独立参照结果包：`artifacts/2026-10-05-icc-mpet-lab/decimal-reference.json`，SHA-256：`3be5b8f6263de4f9c2a4ce0dbc754b6d6418abb2cc06bc48388a0f95adc91607`。参照脚本 SHA-256：`3e5a86349a5351abea647323abc097ca9124db2c1eae8916f640cb7365cab0cb`。

90 位 Decimal 的核心结果：

```text
D2B 设备 [0.5, 0.4, 0.6] -> PCS Lab [50.0, -26.0, 25.0]
D2B 解码后的项目 Lab [0.5, -26.0, 25.0]
B2D Lab [25.00, 12, -20] -> [0.24999999441206455000, 0.549019640311598756, 0.423529436811804740]
D2B -> B2D -> 设备 [0.4999999888241291000, 0.4000000236555933620, 0.6000000354833900750]
```

链路结果与 Swift float32 MPE 参数的最大绝对差保持在 `2e-7` 契约内；没有降低 Double 最终路径、网格、位宽、插值规则或既有阈值。

`Scripts/verify-native-numerics.sh` 复验退出码为 0，覆盖 66 项原生检查、11 项 Node 契约、54 个 CUBE 生成/读回案例和 Swift 命令行检查。日志 SHA-256：`c47de388c35207618eb684a3505afe28dc08cf3930cfcedca1d1f5558a77f2ba`。

## 未覆盖

本阶段不覆盖 ICC 任意通道、其他 MPE 处理元素、传统 `mft`/`mAB` Lab absolute 的全部合法标签变体、真实非 synthetic profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR、第三方调色软件往返、UI、真机性能或发布清单。传统 Lab PCS absolute 的三通道比例子集另见[独立验收](2026-10-05-icc-absolute-lab.md)。`docs/native-validation/full-scope-acceptance.json` 仍不存在，Goal 保持 `active`。
