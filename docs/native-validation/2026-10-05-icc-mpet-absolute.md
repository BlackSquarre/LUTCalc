# ICC 四种 rendering intent 的三通道 MPE 子集验收

日期：2026-10-05

## 范围

本验收覆盖 ICC.1:2022-05 的 `D2B0`/`B2D0` perceptual、`D2B1`/`B2D1` media-relative、`D2B2`/`B2D2` saturation 和 `D2B3`/`B2D3` ICC-absolute 三通道 RGB/`XYZ ` profile。`ICCMPETransform` 支持 `cvst` 的公式曲线（公式类型 0、1、2 和多段 breakpoint）、中间段 `samf` 线性插值、`matf`、float32 `clut`、`bACS`/`eACS` pass-through，以及严格的通道、偏移、共享数据区间和有限浮点检查。MPE 元素之间不做额外裁切；CLUT 仅按规范将输入裁切到 `0...1`，四条 MPE 路径均不读取 `mediaWhitePointTag`。

`ICCRGBProfileLink` 在四种 intent 下分别要求 source/target 同时具有对应的 `D2B0`/`B2D0`、`D2B1`/`B2D1`、`D2B2`/`B2D2` 或 `D2B3`/`B2D3`，再选择对应 MPE；没有对应成对标签时才回到既有支持路径或明确拒绝。只有一侧有对应 MPE 标签、LUT/Lab absolute、非三通道、未知元素和非法 profile 均明确拒绝。

## 来源与工具链

- 规范：ICC.1:2022-05，临时来源文件 `/tmp/icc-1-2022-05.pdf`，SHA-256：`aad8e33128635893e38ae780def3b29e661e4541be03cb235c67dd94d558001b`。
- 工具链：Apple Swift 6.4（swift-driver 1.168.6），Xcode 27.0（27A266a），macOS arm64。
- 实现源码：`Native/Packages/LUTKit/Sources/LUTPreview/ICCMPETransform.swift`；profile 分派：`Native/Packages/LUTKit/Sources/LUTPreview/ICCRGBProfileLink.swift`。
- 源码 SHA-256：`ICCMPETransform.swift`=`ccb08789d62092b4be6cd0bdbe7e5c2d6e7e01f9ccd24d83ecbc21b8bce08b9b`；`ICCRGBProfileLink.swift`=`a3d9ec2034f83da06f56c1d439fc9ca629266e3434d781c700c01b735e8857e1`；MPE 契约=`b278bff650920f4388cdabcda0f6bee35bb6c5f705887a93444f1af3bda269eb`；profile route 契约=`6d7c3a602852d17e16f77708ae983196203f69446fa914be60874b7dd20e642f`。

## 契约与实际命令

先增加 breakpoint 等号归属、ACS pass-through、相同元素区间共享、降序 breakpoint、非有限 matrix float、`samf` 中间段插值、首尾拒绝和四种 intent 的 MPE 成对路由契约，再运行：

```sh
swift test --package-path Native/Packages/LUTKit --filter 'ICCMPEContractsTests'
swift test -c release --package-path Native/Packages/LUTKit --filter 'ICCMPEContractsTests|ICCRGBProfileLinkContractsTests'
bash Scripts/verify-native-fast.sh
bash Scripts/verify-native-release.sh
```

结果：定向 Debug 15 项 MPE、18 项 profile route，含四种 intent 的 MPE 路由与不完整 pair 契约；定向 Release 15 项 MPE、18 项 profile route 均为 0 失败。完整 Swift Release 819 项、Node 11 项均通过；发布入口的 66 项原生检查、三平台未签名 Release 构建和 3 个 App 包审计通过。Release 入口退出码为 2，唯一失败是缺少真实 `docs/native-validation/full-scope-acceptance.json`，没有创建或伪造该文件。

结果包位于 `docs/native-validation/artifacts/2026-10-05-icc-mpet-absolute/`：`targeted-release.log`、`full-fast.log`、`release-gate.log` 及对应退出码文件。最终日志 SHA-256：`266ca013b645eebab638f9e09838c9050a50197e304b669f133ab105e1d2e715`、`c63b4482a55713454d58e73cf6bd0071a860420009aaf0a8f0cf37c60c959c6b`、`57c04b478aecfccc0cf817190458d6c5ba11e50ad600e44675119dc966e188b7`。

## 数值结果

契约使用独立构造的 RGB/`XYZ ` profile 和公式预期：公式和 `samf` 插值先按规范量化为 float32 再以 Double 参照，断言误差不超过 `1e-15`；float32 MPE linking 断言误差不超过 `2e-7`。负 PCS、大于 1 PCS、CLUT 入口裁切和元素输出不裁切均有覆盖。该结果是结构和最小数值契约，不是对任意真实厂商 profile 的逐码独立参照；没有降低网格、位宽、插值规则或 `Double` 最终路径。

## 未覆盖范围

完整 ICC 仍未完成：真实 profile 独立参照、传统 tag 的任意通道 linking、黑点补偿和 gamut mapping 均未接通。本规范版本的 MPE 元素集合已由 `cvst`、`matf`、`clut`、`bACS` 和 `eACS` 覆盖；未知未来元素必须拒绝并回退。`parf` 只接受 type 0、1、2，传统 `para` 的 type 3、4 不属于 `cvst`。当前语义拒绝 `samf` 首段；末段在前一段提供隐含起点且延伸到归一化终点时允许，详见 2026-10-06 末段采样验收。ColorSync、HDR/EDR、第三方软件往返、签名发布和完整全量验收清单仍未完成。本记录只关闭上述四种 intent 的三通道 mpet 子集，Goal 保持 `active`。
