# H13 ImageIO 灰度像素布局阶段验收

日期：2026-09-25。Goal 仍 active。本阶段补齐 H13 的一个非 RGB 像素布局子集，保持 Swift、Double、alpha 语义和显式来源解释边界，不引入隐式色彩转换。

## 范围与实现

`PreviewImageDecoder` 现在接受 ImageIO 的 `.monochrome` 色彩模型：

- 灰度 8 位和 16 位单通道样本复制到 `RGBA64` 的 R/G/B 三个 Double 通道。
- 灰度+alpha 8 位样本保留灰度值并单独读取 alpha。
- 8 位默认字节序、16 位大端/小端字节序与已有 RGB 路径保持相同边界。
- 灰度预乘 alpha 仍报告 `.premultiplied`；本阶段没有擅自反预乘或做色彩空间转换。
- 其他通道数、解码状态和布局继续拒绝。

## 契约先行

先扩展研发夹具生成器和 `LUTImageChecks`，加入灰度 8/16 位及灰度+alpha PNG 检查。旧解码器对真实灰度夹具按预期返回 `unsupportedColorSpace`；随后实现 `.monochrome` 分支并重新编译，以下检查全部通过：

- 灰度 8 位码值 32、224 逐码归一化；
- 灰度 16 位码值 16384、49152 逐码归一化；
- 灰度+alpha 的 64/128 与 192/255 逐码归一化；
- R/G/B 相等、alpha 独立且既有 RGB/ICC/TIFF/JPEG/方向/预算/CRC/重复 `iCCP` 夹具不退化。

## 真实 ImageIO 验证

```text
python3 tools/native-validation/generate-preview-fixtures.py <临时目录>
sips -s format jpeg <临时目录>/rgb8.png --out <临时目录>/rgb8.jpeg
swift run -c release --package-path Native/Packages/LUTKit \
  LUTImageChecks <临时目录>
```

结果：退出码 0。夹具生成器现明确包含 RGB/灰度 PNG 8/16 位、嵌入 ICC、TIFF 16 位和方向 1–8；`LUTImageChecks` 全部通过。

## 集中 Release 回归

执行 `bash tools/native-validation/verify-native-release.sh`，结果如下：

- `swift test --list-tests`：169 项；Swift Release XCTest 全部通过，`PreviewContractsTests` 14 项通过。
- 旧 Node/Python 契约、33³/65³ 批量数值生成和独立逐节点读回通过。
- macOS Release、iOS Simulator Release、iOS generic Release 均 `BUILD SUCCEEDED`。
- 3 个 App 包资源审计通过。
- 完整日志：`/tmp/lutcalc-h13-grayscale-release-full.log`。
- 日志 SHA-256：`c1cae3b1566b08cc24c186242d0d57aae026115bb3eee6a2ec0b2e1d1f8d42b4`。

发布入口仍以退出码 2 结束，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建占位清单。ICC 完整类型、显示色彩管理、整图显示、HDR/EDR、Files/File Provider、真机 SPI3D 读回/取消和其他未支持像素布局仍未完成，Goal 保持 active。
