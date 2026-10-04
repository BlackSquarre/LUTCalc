# H04 三种 CUBE 写出方言阶段记录

日期：2026-09-23。旧方言依据 `js/lut-cube.js` 的 `cubeLUT.header()`，源码 SHA-256 为 `96e33d0b3dbd6467e45b54a97dac7f06e86b6303f2f98eacfa1cd47bdd4c5da5`：flavour 1 不写域指令，flavour 2 写相应 `LUT_1D/3D_INPUT_RANGE`，flavour 3 写 `DOMAIN_MIN/MAX`。当前 Swift 方言命名分别为 `general`、`resolveInputRange`、`domain`，默认继续使用 `domain` 以兼容此前原生写出结果。

先增加 `LUTFormatChecks` 契约入口，要求 1D/3D 各写出三类文件；统一范围与逐通道不同范围均保留，不能表达的组合要明确拒绝。第一次运行因 `CubeDialect` 缺失而编译失败。实施后，`general` 仅允许单位域；`resolveInputRange` 只允许三通道相同的范围；`domain` 支持逐通道范围。旧版 flavour 1 对非单位域会省略信息，新版明确报 `unsupported`，避免静默改变 LUT 语义。

实际命令：

```text
swift run --package-path Native/Packages/LUTKit LUTFormatChecks /tmp/lutcalc-cube-dialects-20260923
python3 tools/native-validation/verify-cube-dialects.py /tmp/lutcalc-cube-dialects-20260923
tools/native-validation/verify-native-subset.sh
```

前两条通过：Swift 自读回六份 Double 样例完全一致；独立 Python 逐行验证标题、尺寸、方言域指令、精确行数、有限值和样本通道，最大尺度化误差 `0`，门槛保留 `2e-12`。子集脚本已加入动态临时目录中的六方言独立检查，整套再次退出码 `0`。六份研发文件只在 `/tmp`，不进入 App；样本包括负值和超白。当前 `CubeWriter.serialize` 默认方言未改变，分块文件 sink 仍使用 `domain`。

修改文件 SHA-256：`LUTFormats/Cube.swift` 为 `9ebfc905ec7b080b4194b71fa94d7b24d9df74d353ecfc05a62777b0c117ef2d`；`LUTFormatChecks/main.swift` 为 `190e24b6f6e6d0d78d291a098d6e7e2e18e9b7554b0f251fe8cb680fb9bbd528`；独立校验器 `verify-cube-dialects.py` 为 `2fa9ec56faabffb5ff7d7e8446e713f8c163da5780b1300b662c84f589382597`；`verify-native-subset.sh` 为 `08e2feedb1d76cf710179c76f2952a6cc87ab96dd0cf9a0801331adacea773f3`；`Package.swift` 为 `5d9cc94206ee82f8c1afc61c9cde384533e60bfd83024379c40088456ec3b5d2`。另扩充 `Tests/LUTFormatsTests/CubeContractsTests.swift`，本机缺 XCTest，未执行。

仍缺真实目标软件导入、方言对指数记数法/标题长度等限制、独立大文件解析与 Mac/iOS 文件事务。基础解析仍拒绝组合 shaper+3D；旧 `.cube` 的完整读写能力及 FLOW-01 不能据此勾选。
