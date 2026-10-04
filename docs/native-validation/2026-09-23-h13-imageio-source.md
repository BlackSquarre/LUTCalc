# H13 图像原始样本解码阶段验收

日期：2026-09-23。状态：阶段通过，H13/UI-03 尚未完成。

## 契约与实现

使用 Apple ImageIO 解码文件，并从 `CGImage` 的数据提供者读取明确支持的 RGB 8/16 位整数布局，逐通道转成 Double。Apple 的 [CGImage 位图说明](https://developer.apple.com/documentation/coregraphics/cgimage/init%28width%3Aheight%3Abitspercomponent%3Abitsperpixel%3Abytesperrow%3Aspace%3Abitmapinfo%3Aprovider%3Adecode%3Ashouldinterpolate%3Aintent%3A%29)定义提供者原始数据与位图参数的关系；当前实现仅在布局、位序与颜色模型明确时解释字节。读取前用文件大小、图像元数据尺寸和 `PreviewRequest.maxPixels` 限制资源；解码后核对实际尺寸、像素布局、每行字节数、64 MiB 解码上限和数据长度，拒绝带额外 `decode` 映射的图像。支持已核对的 RGB/RGBA、无 alpha 填充、非预乘或预乘末尾 alpha；其他布局和非 RGB 色彩空间明确拒绝。当前不执行 ICC 转换，返回解码后色彩空间名称和 ICC 数据供后续显式色彩流程处理；这些资料可能由 ImageIO 推断，不能直接声称源文件内嵌 ICC。方向 1–8 以 Swift 坐标重排为取样顺序，其他方向值明确拒绝。

研发夹具由独立 Python 标准库生成 PNG 8/16 位与 TIFF 16 位，包括方向 1–8 和预乘 alpha；JPEG 8 位由系统 `sips` 从 RGB PNG 生成。夹具只在验证临时目录，未加入 App。JPEG 为有损格式，本阶段只验位深、尺寸、alpha 和色彩空间元数据，不把它计入逐码值零误差结论。

## 修改文件和版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTPreview/PreviewImageDecoder.swift` | ImageIO 有界解码、原始码值、alpha、方向与色彩元数据 | `b652ece925eb4a251b8cac4cbb1fbbe7e1f4ec3965bdb5b2b1311cc0acb8780e` |
| `Native/Packages/LUTKit/Sources/LUTImageChecks/main.swift` | 无损数值、JPEG 元数据、方向 1–8、预乘 alpha、资源预算、损坏文件/链接拒绝契约 | `c43d52fd90a39374cc95dc3e7539a6f84b402cef9c06b11bdeebb2522746ca2c` |
| `Native/Packages/LUTKit/Package.swift` | 新增契约可执行 target | `eedff841495e206e20280b130a737d5311e469a4ff2941a15a1964066fc673ca` |
| `tools/native-validation/generate-preview-fixtures.py` | Python 标准库生成 PNG/TIFF 与超大元数据研发夹具 | `848a943d1177c41c95e4f462f5bb51bd8dad60808cc691b4419632f67c16d923` |
| `tools/native-validation/verify-native-subset.sh` | 接入生成夹具、系统 JPEG 与 Release 解码契约 | `d9bdbe0c936e029d2cc117e274dfe212d49c1c42cb6c3273068039ba6078cbaf` |

最终使用的 `/tmp/lutcalc-preview-budget-valid-20260923/` 夹具哈希：`rgba8.png` 为 `894c9b3888193e859486d2a8766199834135a650236735673577ca16777688b2`，`rgba16.png` 为 `d9635505be1220d75f16bd7743078b17a231e46663559809a013d89900211ee1`，`rgba16.tiff` 为 `cf8684a70da8fd9de527dfcdf805a578499b8cd0f2eb132cff138e0682de9a4e`，`premultiplied16.tiff` 为 `3353ba4290a148db5f346cfcc956daf1256bf4ab4e614f9d4ddde551f177e9be`，`orientation-6.tiff` 为 `722cd1e27e9ae7e2ad8efa8e09e1887f6345137d20fbdf20d790023f51de7c32`，`oversized-header.png` 为 `b8c4640fa8527986566bbe56f2396e8574c071fb697e8676f52538c2dbaab38c`，系统 `sips` 写出的 `rgb8.jpeg` 为 `7214ca8093db9c18d1310279d6280b6ea71b0312b2147ca162449acc80e06909`。这些仅为研发验证文件。

## 实际验证

- Apple Swift 6.2.1，arm64 Command Line Tools；Python 3.14.6；`sips-316`。
- 先增加 `LUTImageChecks` 契约，`swift build --package-path Native/Packages/LUTKit --product LUTImageChecks` 因缺 `PreviewImageDecoder` 等接口失败；随后实现。
- 初版执行 `python3 tools/native-validation/generate-preview-fixtures.py /tmp/lutcalc-preview-fixtures-tiff-20260923`、`sips -s format jpeg /tmp/lutcalc-preview-fixtures-tiff-20260923/rgb8.png --out /tmp/lutcalc-preview-fixtures-tiff-20260923/rgb8.jpeg`、`swift run --package-path Native/Packages/LUTKit LUTImageChecks /tmp/lutcalc-preview-fixtures-tiff-20260923`，均退出码 0。PNG 8/16 位、TIFF 16 位全部核对的整数码值以 `Double(code)/255` 或 `Double(code)/65535` 精确相等；没有经过 8 位截图或压低 16 位。初版对旋转 TIFF、符号链接、损坏文件明确拒绝；旋转能力在下述后续步骤补齐。
- 最终执行 `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-image-validation-20260923.log 2>&1`，退出码 0。静态边界检查覆盖 37 个 Swift 源文件；旧版 Node 9 项通过；七份 CUBE 方言独立读回通过；新增 ImageIO 契约在 Release 运行通过。没有调整冻结夹具或数值阈值。
- 随后先增加方向 1–8 的独立 TIFF 契约；`swift run --package-path Native/Packages/LUTKit LUTImageChecks /tmp/lutcalc-preview-orientation-20260923` 按预期以 `unsupportedOrientation` 失败。实现 Swift 坐标重排后，同一目录重跑退出码 0。再增加预乘 TIFF 契约，`swift run --package-path Native/Packages/LUTKit LUTImageChecks /tmp/lutcalc-preview-alpha-20260923` 退出码 0；16 位原始 R 与 alpha 均精确等于 `32768/65535`。
- 方向扩展后的最终入口 `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-image-orientation-validation-20260923.log 2>&1` 退出码 0；旧版 Node 9 项及原生其余契约均通过。未改冻结阈值。
- 随后按 Apple 位图契约增加 `decode` 映射拒绝及 64 MiB 原始数据预算；把损坏文件/符号链接夹具放进任务自有临时目录，连续两次运行同一 `LUTImageChecks` 均退出码 0。最终执行 `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-image-final-validation-20260923.log 2>&1`，退出码 0；Release 解码、Node 9 项及其余原生契约均通过。没有改变导出网格、位宽或阈值。
- 检查 `/Applications` 与用户应用目录，没有 `Xcode*.app`；`xcode-select -p` 指向 `/Library/Developer/CommandLineTools`，`xcrun --sdk iphonesimulator --show-sdk-path` 找不到 SDK。实际运行 `tools/native-validation/verify-native-release.sh > /tmp/lutcalc-release-gate-20260923.log 2>&1`，退出码 2，明确停在完整 Xcode 门槛。不能计为 macOS/iOS App 构建或发布通过。
- 增加 5000×5000 PNG 元数据和 256 MiB 以上稀疏文件契约。首次仅构造不完整 PNG 时 ImageIO 返回 `invalidImage`，没有触发目标路径；改为完整压缩 PNG 后，`swift run --package-path Native/Packages/LUTKit LUTImageChecks /tmp/lutcalc-preview-budget-valid-20260923` 退出码 0，两种超预算文件均被 `resourceLimit` 拒绝。最终 `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-image-budget-validation-20260923.log 2>&1` 退出码 0；Node 9 项和全部当前原生子集契约通过。

## 未覆盖范围

本阶段不是 UI-03 完整验收：其他位序/布局、CMYK/灰度、动态尺寸与动画仍未支持；JPEG 数值未与独立解码器比较。尚未证明嵌入 ICC 与推断色彩空间的判别、显示空间转换、显式 Log 输入流程和 Core Image 交互路径。文件授权、Files/File Provider、macOS/iOS `.app` 构建、真机与屏幕色彩验证仍未执行；当前本机只有 Command Line Tools。不得将此阶段称为预览功能或发布完成。
