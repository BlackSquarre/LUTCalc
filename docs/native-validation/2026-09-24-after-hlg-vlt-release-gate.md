# HLG 与 VLT 接线后完整回归和发布门槛

日期：2026-09-24。范围：当前 Swift 工作区的静态/数值/构建回归及发布证据结构检查；不是完整迁移验收。

## 验证

运行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-release-current-stable-20260924.log`，SHA-256 `fc13c8428b0632cd7b35be628086d9ebb581808fc781d319a8b0f4b429402460`。旧 Node 测试 11 项、Python App 包审计契约 3 项、Swift Release XCTest 99 项均通过，0 失败。原生子集静态与命令行检查通过，包括 HLG 33³/65³ 独立逐节点检查；macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`。三个实际 App 包的禁用 LUT/脚本文件及 WebKit/JavaScriptCore 直接链接审计通过。

发布入口最终退出码 2，明确报缺少 `docs/native-validation/full-scope-acceptance.json`。该文件只有真实完整能力、数值、设备、授权和发布证据齐备后才能建立；本次没有生成占位清单。现有包审计也不证明二进制中完全不存在等价采样表，仍需完整源码/依赖和产物审计。

## 运行中脚本诊断

此前一次完整入口在 Rec.709 33³ 导出后出现 `verify-native-subset.sh: line 154: 3: command not found`，日志 `/tmp/lutcalc-release-after-hlg-vlt-20260924.log`。当前第 154 行的字节和 Bash 续行正常，`bash -n` 通过；脚本修改时间接近当时验证时间，可能是运行中原地修改使 Bash 续读到部分内容，但没有当时源码快照，不能证明原因。本次在编辑结束后重跑完整入口，从 Rec.709 检查继续经过全部子集、测试和构建，未再出现 127。

## 分项状态

- 代码：HLG 场景曲线、VLT 文档导出等本轮子集有契约；其余 H01–H14 和完整旧能力仍未全部实现。
- 数值：已列出的冻结检查和 99 项 Swift 测试通过；未覆盖全部旧管线、HDR 显示和第三方格式验收。
- 构建：三平台 Release 与三包有限资源审计通过。
- 真机：本日志不含最新版 SPI3D 真机生成、容器取回和逐节点比较；以独立真机记录为准。
- 发布：真实全量验收清单缺失，门槛未通过。
