# ICC device-link A2B0 数值验收

日期：2026-10-05

## 范围

本阶段只闭合用户主动导入的 ICC `link` profile 单个 `A2B0` device-to-device 路径。profile class 必须为 `link`，使用头部声明的 rendering intent；A2B0 支持 `mft1`、`mft2` 和 `mAB`，反向 `mBA`、缺少 A2B0、class／维度／intent 不一致均拒绝。没有把该子集接入默认系统色彩管理、项目 schema 或 UI。

## 先行契约与修正

先行契约覆盖头部 intent、A2B0 选择、mft2、mAB、任意声明维度、错误 profile class、错误 intent、缺失标签和反向标签。真实 profile 参照首次失败后定位到 `mAB` 矩阵解码：ICC tag 使用连续 9 个 3×3 s15Fixed16 系数，随后 3 个 s15Fixed16 offset；旧实现按行交错读取，导致真实 profile 的矩阵错位。实现已修正，合成矩阵夹具同步改为规范布局。

## 真实参照

使用本机 Little CMS 2.19（`linkicc` 3.3、`transicc` 5.1）生成临时 profile：

```sh
/opt/homebrew/bin/linkicc -t1 \
  -o /tmp/lutcalc-srgb-p3-link-20261005.icc \
  '/System/Library/ColorSync/Profiles/sRGB Profile.icc' \
  '/System/Library/ColorSync/Profiles/Display P3.icc'
```

profile 不复制进仓库。SHA-256 为 `b71246f895479ec069e3025dd5ec1a56513e1dfd44bae8ac1549dd6ce0e9156b`。

独立参照使用 Little CMS 公开 C API `cmsReadTag(..., cmsSigAToB0Tag)` 和 `cmsPipelineEvalFloat`，未导入 Swift 实现或 profile payload 到参照程序。工具链为 Xcode 27.0、Swift 6.4、Apple clang；三点输出如下：

```text
0.444083303 0.594644070 0.782909870
0.123826966 0.197497517 0.291859299
0.917524993 0.200213626 0.138521403
```

Swift Release 定向测试使用相同三点，24 项（`ICCDeviceLinkContractsTests` 6 项与 `ICCMABContractsTests` 18 项，其他测试包无匹配项）全部通过。Swift Double 与 float32 参照的最大差低于 `3e-5`；该阈值只反映独立参照的 float32 阶段，不改变生产计算的 Double 精度。

`transicc -l` 的 CGATS 前端对相同文件给出另一组量化结果，和 Little CMS 公开 `cmsPipelineEvalFloat` 不一致；本阶段将该差异记录为工具前端差异，不把 CLI 输出作为规范数值参照，也没有放宽生产实现来匹配它。

## 实际命令与结果

```sh
swift test --package-path Native/Packages/LUTKit \
  -c release \
  --filter 'ICCMABContractsTests|ICCDeviceLinkContractsTests'
```

退出码 `0`。完整日志位于 `artifacts/2026-10-05-icc-device-link/release.log`，SHA-256 为 `c5d06c4ebd5b12e0e80a8d9ff246463ce505b634bc28f4c7e4ee15460660e29f`。参照输出、profile／源码哈希位于同目录。

修正后的 Swift Release 全量回归：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`，8 个测试包合计实际执行 `895` 项，2 项既有外部夹具跳过，0 失败；完整日志 `artifacts/2026-10-05-icc-device-link/full-release.log`，SHA-256 为 `96d156ed4b58bffcba9472e8aa13a45f34799bb00b41cc514ddfc0dbf38f78ab`。原生数值门禁 `Scripts/verify-native-numerics.sh` 退出码 `0`，日志 `artifacts/2026-10-05-icc-device-link/numerics-gate.log`，SHA-256 为 `620c5320771095e40e8b98c10f28c7073c2ef03312d40291a7ade62f4600cac6`。

## 未覆盖范围

本阶段不代表完整 ICC：其他 profile class、`mpet` 的全部元素组合、其他 rendering intent、black point compensation、gamut mapping、ColorSync、HDR/EDR、真实第三方 profile 全量逐码参照、目标调色软件往返、`.labin`、直接查表注册、LUTAnalyst 任意三维反求和发布清单仍未完成。`docs/native-validation/full-scope-acceptance.json` 未创建，Goal 继续保持 `active`。
