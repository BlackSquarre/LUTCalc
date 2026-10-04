# `.3dl` 子集后的完整回归与发布门槛

日期：2026-09-24。此记录针对 Flame/Assimilate `.3dl` 解析、写出子集与 H12 清单重复键修正均已落盘后的源码状态；不代表完整迁移验收。

## 实际执行

执行 `bash tools/native-validation/verify-native-release.sh`，本机完整日志为 `/tmp/lutcalc-release-after-3dl-20260924.log`。Xcode 27.0、Apple Swift 6.4。旧 Node 子集 9 项通过，Python App 包审计契约 3 项通过；Swift Release XCTest 共 66 项、0 失败。macOS、iOS Simulator、iOS generic 三个未签名 Release 构建各显示 `BUILD SUCCEEDED`；三个实际 App 包的资源审计通过，未检出列明的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

完整入口最终退出码 **2**：`check-release-evidence.py` 报告缺少真实的 `docs/native-validation/full-scope-acceptance.json`。H01–H14、完整功能、数值、设备、兼容性、许可和发布证据尚未齐备，因此没有创建该清单，也没有把子集回归写成发布通过。资源审计本身不能证明二进制中没有等价采样表，仍需完整源码与构建产物审查。

## 状态边界

本次结果证明当前代码在上述测试和未签名构建范围内可通过；`.3dl` 的第三方兼容、App 导出接线和完整 FULL-06 未验证。iPhone Air 本轮仍被 `devicectl` 列为 `unavailable`，最新版 SPI3D 的真机生成、从本 App 容器取回及独立逐节点比较仍为空缺。既有 CUBE 真机数值证据只适用于此前版本和对应导出路径。
