# `.ilut`、`.olut` 与 Assimilate `.lut` 后的完整回归

日期：2026-09-24。范围：截至本轮三种 1D 格式子集及 `.ilut` App 接线完成时的源码；不包含此后接线或旧设置迁移的改动。原始日志为 `/tmp/lutcalc-release-after-ilut-olut-assimilate-20260924.log`。

## 实际结果

执行 `bash tools/native-validation/verify-native-release.sh`，最终退出码 2。前置原生边界检查通过；旧网页 Node 测试 11 项通过、0 失败；Python 包审计契约 3 项通过、0 失败。Swift Release 包级 XCTest 按八个顶层测试包计数：`LUTSharedUI` 13、`LUTProject` 6、`LUTPreview` 2、`LUTJobs` 16、`LUTFormats` 39、`LUTCore` 10、`LUTCatalog` 2、`LUTAnalysis` 4，合计 **92 项**，均为 0 失败。这个合计只计每个 `.xctest` 汇总行一次，不重复计入各测试类和 `All tests` 行。

macOS、iOS Simulator、iOS generic 三个 Release 未签名构建均显示 `BUILD SUCCEEDED`；实际三个 App 包的禁用 LUT/脚本资源及 WebKit/JavaScriptCore 直接链接审计通过。日志中的现有数值契约维持通过，包括 D-Log2 33³ 往返最大绝对误差 `1.4202528042517315e-13`，以及旧无调节链和阶段诊断检查；未更改冻结精度门槛。

入口最后因缺少真实的 `docs/native-validation/full-scope-acceptance.json` 而退出码 2。当前没有全量功能、许可、二进制等价采样表、真机和发布证据；不创建虚构清单，也不将此阶段回归记为发布通过。

同期 `xcrun devicectl list devices` 退出码 0，三台物理 iPhone 均为 `unavailable`，同名 iPhone Air 的 `connected` 行属于模拟器。最新版 SPI3D 真机生成、App 容器取回和独立逐节点比较仍未进行。
