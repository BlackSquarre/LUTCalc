# ICC 传统 Lab PCS absolute colorimetric 子集验收

## 范围

本轮只处理用户导入的 RGB/Lab ICC profile 在 `absoluteColorimetric` 下、没有可用 `D2B3`/`B2D3` MPE 对时的传统 `mft1`/`mft2`/`mAB`/`mBA` 路由。依据 ICC.1:2022-05 §6.3.2.2 公式 (1)–(6) 和 §6.3.2.3 公式 (7)–(9)，先把 source 的 media-relative PCS Lab 解码为 PCS XYZ，再按 source/target `mediaWhitePointTag` 比例换算，最后编码为 target 的 media-relative PCS Lab 并进入 target device 变换。

本轮不处理任意通道、`D2B3`/`B2D3` 之外的 MPE 扩展、黑点补偿、gamut mapping、ColorSync 或厂商 profile。用户 profile 的 LUT 字节只在初始化时解析，不进入 App 资源。

## 先行契约与实现

- 传统 Lab `mft` 与 `mAB/mBA` 变换新增 media-relative PCS XYZ 的显式桥接方法。
- `ICCRGBProfileLink` 新增 `labAbsolute` 路由，读取并校验两侧 `wtpt` 的 `XYZ ` payload，使用 `sourceWhite / targetWhite` 逐通道比例。
- 缺失或非正的 `wtpt` 明确返回 `.lab(.missingMediaWhitePoint)` 或 `.lab(.malformedMediaWhitePoint)`。
- 传统 LUT/XYZ absolute 仍拒绝；已有 `D2B3`/`B2D3` Lab MPE 仍按 float32 PCS 直接路由，不使用 `wtpt`。

契约覆盖：传统 `mft2` 路由、传统 `mAB/mBA` 路由、不同媒体白点、缺少 `wtpt`、传统 LUT absolute 拒绝，以及既有 matrix/TRC/MPE/relative 路由回归。

## 独立参照

参照脚本为 `tools/native-validation/probe-icc-absolute-lab.py`，使用 Python `Decimal` 90 位和当前 CIELAB D50 常量，不调用 Swift 实现。输入为 `[0.5, 0.5, 0.5]`，source `wtpt=[0.8,1.1,0.9]`，target `wtpt=[1.2,0.9,1.5]`。独立目标 target Lab 编码为：

```text
[0.5456575525990818272615533377782944...,
 0.4980657576101667470841807737391569...,
 0.5013143780971089928773369105743240...]
```

结果文件：`artifacts/2026-10-05-icc-absolute-lab/decimal-reference.json`。

SHA-256：

- `decimal-reference.json`: `99b4cb83c5273dbbcf85c266d6134547a9eaee1c0edfd80ef5ad10c80398c54c`
- `decimal-reference.log`: `b29de65111569038227f58d75cf2307101a174e4776b3333dbd36fe887269c47`

## 实际验证

工具链：Xcode `27.0 (27A266a)`、Swift `6.4`、Apple Silicon macOS。

```sh
python3 tools/native-validation/probe-icc-absolute-lab.py
python3 -m py_compile tools/native-validation/probe-icc-absolute-lab.py
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter ICCRGBProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ICCRGBProfileLinkContractsTests
```

结果：Debug 定向 `26` 项通过；Release 定向 `26` 项通过；独立 Decimal 参照退出码 `0`。Release 日志和退出码文件位于 `artifacts/2026-10-05-icc-absolute-lab/`，SHA-256 为：

- `icc-lab-release.log`: `bc10db529bc85e3e0b25913f01bfb30e56d2b7d7013b12805e15079c8aec993c`
- `icc-lab-release.exit`: `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`

## 未覆盖

这是传统 Lab PCS absolute 的三通道数学子集，不代表完整 ICC。任意通道、完整 profile 类型、传统 `mft1/mft2/mAB/mBA` 的所有合法变体、真实非 synthetic profile 的逐码参照、perceptual/saturation、黑点补偿、gamut mapping、系统 ColorSync、HDR/EDR 和第三方软件往返仍未完成。9 个 `.labin`、45 个直接查表注册、完整 HDR/OOTF、LUTAnalyst 全局反求和发布清单仍保持未完成；Goal 继续为 `active`。
