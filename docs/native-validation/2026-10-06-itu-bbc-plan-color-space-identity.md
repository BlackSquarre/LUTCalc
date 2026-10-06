# ITU Proposal 与 BBC 计划色域身份验收

日期：2026-10-06

## 范围

本次只闭合计划身份，不修改 ITU Proposal、BBC Gamma 或 BBC WHP283 的 Double 公式、分支边界、网格、位宽和阈值。覆盖 `ituProposal400`、`ituProposal800`、`bbc04`、`bbc05`、`bbc06`、`bbcWHP283400`、`bbcWHP283800`。

## 契约与红测

在实现修改前新增色域变化契约：相同 transfer、不同输入或输出色域必须得到不同 `planVersion`，并且基线身份必须包含 `inSpace` 与 `outSpace`。旧实现定向 Release 红测失败：ITU、BBC Gamma、BBC WHP283 各有 4 个断言失败，证明原身份遗漏色域字段。

## 实现

`TransformPlan.basePlanVersion` 将三类分支统一改为 `directionalAndSpaces`，身份现在包含输入 transfer、输出 transfer、输入色域和输出色域。数值实现保持不变。

## 实际验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ITUProposalTransferContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter 'ProPhotoBBCContractsTests|BBCWHP283ContractsTests'
```

结果：两次命令均退出码 0；ITU Proposal 5 项通过，BBC WHP283 5 项通过，BBC Gamma/ProPhoto 6 项通过。既有公开公式边界、非有限值拒绝、数据包装往返和目录注册契约继续通过。

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

## 未覆盖

本记录不代表 `.labin`、直接查表替代、完整 ICC/HDR/OOTF、三维全根完备性、真实外部软件往返或发布验收完成；这些仍按路线图保持未完成。
