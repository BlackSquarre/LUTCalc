# ICC MPE 处理元素通道数边界验收

## 范围

本轮处理用户导入 `multiProcessElementsType`（`mpet`）的结构边界。每个 MPE 处理元素必须有至少一个输入通道和至少一个输出通道；零通道元素不能作为有效处理阶段。该修复不扩展 MPE 元素类型，也不改变已有 `Double` 计算路径。

## 契约与实现

先加入失败契约 `testMPEElementsRejectZeroInputOrOutputChannels`，分别构造 `matf` 的零输入和零输出元素，要求返回 `.unsupportedChannels`。生产解析入口随后在读取元素签名与通道字段后拒绝任一零值，再继续解析 `cvst`、`matf`、`clut` 或 ACS 元素。

## 验证

工具链为 macOS SwiftPM，命令如下：

```sh
swift test --package-path Native/Packages/LUTKit --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
git diff --check
```

Debug `ICCMPEContractsTests` 28 项通过，Release 28 项通过，均为 0 失败；`git diff --check` 通过。完整输出和 SHA-256 保存在 `docs/native-validation/artifacts/2026-10-06-icc-mpet-channel-count/`。

## 未覆盖范围

本项只关闭零通道 MPE 结构边界，不代表完整 ICC profile class、所有 rendering intent、真实 profile 逐码参照、BPC、gamut mapping、ColorSync、全部未来 MPE 元素、HDR/EDR、LUTAnalyst 或发布验收完成。Goal 继续保持 `active`。
