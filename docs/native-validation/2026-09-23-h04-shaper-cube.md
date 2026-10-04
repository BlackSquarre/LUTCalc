# H04 组合 CUBE 阶段验收

日期：2026-09-23。状态：阶段通过，H04 尚未完成。

## 来源与契约

OpenColorIO 的 [Resolve CUBE 格式实现及内嵌格式说明](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/main/src/OpenColorIO/fileformats/FileFormatResolveCube.cpp)明确规定：头部先声明 1D/3D 尺寸及各自可选输入范围，随后是全部 1D 行和红轴最快的 3D 行；应用顺序为 1D shaper → 3D。该来源只用来确定用户导入文件格式和研发验证，不进入 App。组合文件的 `DOMAIN_MIN/MAX` 对两级输入域的归属没有在此来源中定义，本实现明确拒绝这种组合，而不猜测其含义。

## 修改

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTFormats/Cube.swift` | 增加组合解析、Double 逐通道 1D 插值、先 shaper 后 3D 取样、组合写出与共享内存上限 | `ddb341f2c164e1a6b242b283f433b9130f47213e53a87fc047e3270f426cd421` |
| `Native/Packages/LUTKit/Sources/LUTFormatChecks/main.swift` | 组合往返、阶段顺序和畸形输入拒绝契约 | `40dfa4997a0f7366fea9717a989946e14e9611a35c1fda34769536ed9efc0681` |
| `Native/Packages/LUTKit/Tests/LUTFormatsTests/CubeContractsTests.swift` | 同步 XCTest 契约，待完整 Xcode 运行 | `49bbeca191d4bc67c26adfb8887fbc65aae21382f17862ce5516cc989437ee4a` |
| `tools/native-validation/verify-cube-dialects.py` | 独立读取第七份组合样例并核对头部、行序和数值 | `f82ba965d35040b127993b24493376b234eb48d1d8c1a57f6ca5abdfc986ed1f` |

## 实际验证

- Apple Swift 6.2.1，arm64，Command Line Tools；Python 3.14.6。
- 先增加可执行契约，运行 `swift build --package-path Native/Packages/LUTKit --product LUTFormatChecks`，因 `CubeShaper` 与组合接口尚不存在而失败，确认契约先于实现。
- 实现后运行 `swift run --package-path Native/Packages/LUTKit LUTFormatChecks /tmp/lutcalc-h04-shaper-check-2-20260923`，退出码 0。组合文件读写相等；输入 `(0, 0.5, 1)` 经 shaper 后再经 3D 得到 `(0.5, 0.375, 0.25)`，逐通道最大误差小于 `1e-15`。缺失尺寸、重复尺寸、含糊的 DOMAIN 指令、缺行均拒绝；不兼容的组合 `.domain` 写出明确拒绝。
- 运行 `python3 tools/native-validation/verify-cube-dialects.py /tmp/lutcalc-h04-shaper-check-2-20260923`，退出码 0；七份文件的数值误差均为 0。
- 运行 `tools/native-validation/verify-native-subset.sh`，退出码 0；包含 Release 编译、旧引擎 9 项 Node 测试、既有数值与文件事务契约，以及新增七份 CUBE 独立读回。没有改动冻结夹具或阈值。

## 尚未覆盖

未在 DaVinci Resolve 等目标软件内实测导入；没有双平台 App 构建、Files/File Provider 和真机验证。当前只支持线性 1D 取样及已有 3D 三线性/四面体规则，其他旧插值仍在 H07 范围。`DOMAIN_MIN/MAX` 与组合文件并用维持显式拒绝。以上均不得计作 H04 或发布验收完成。
