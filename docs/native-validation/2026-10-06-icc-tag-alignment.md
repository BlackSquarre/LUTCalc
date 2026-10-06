# ICC tag offset 对齐验收

日期：2026-10-06。范围：ICC profile tag directory 的资源边界校验；Goal 继续 `active`。

## 契约与实现

ICC.1:2022-05 要求 tag offset 为 4 字节对齐。先加入未对齐但 payload 内容仍完整的合成 profile 契约，确认旧 validator 会接受；随后修复 `PreviewContractsTests`、`ICCLUTProfileLinkContractsTests`、`ICCRGBProfileLinkContractsTests`、`ICCMatrixTRCContractsTests` 的多 tag helper：tag size 仍只记录原 payload 长度，cursor 在追加 0 padding 后移到下一个 4 字节边界。生产 `ICCProfileValidator` 现在对未对齐 offset 返回 `.invalidTagRange`。

## 实际验证

工具链：Xcode SwiftPM，macOS 27 SDK，Swift 6。

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests              # 30 项通过
swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests            # 30 项通过
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCLUTProfileLinkContractsTests   # 10 项通过
swift test --package-path Native/Packages/LUTKit -c release --filter ICCLUTProfileLinkContractsTests # 10 项通过
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCMPEContractsTests               # 26 项通过
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests             # 26 项通过
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests       # 21 项通过
git diff --check                                                                                       # 通过
```

实际日志与 SHA-256 保存在同目录 artifact。完整 ICC、第三方 profile 逐码参照、BPC、gamut mapping 和 ColorSync 仍未完成。
