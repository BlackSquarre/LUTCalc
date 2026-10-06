# ICC MPE 曲线 breakpoint 域边界验收

日期：2026-10-06。范围：用户导入 ICC `curf` 曲线中 breakpoint 的结构校验；Goal 继续 `active`。

## 契约与实现

ICC.1:2022-05 的分段曲线 breakpoint 必须位于归一化 `0...1` 域，并按递增顺序划分非零宽度区间。原实现只检查非降序，因而会接受域外值和重复值。先新增契约覆盖 `[-0.01, 0.5]`、`[0.5, 1.01]` 与 `[0.5, 0.5]`，并将旧的“重复点可接受”测试改为明确的 malformed 拒绝；合法 breakpoint 命中仍由 `testBreakpointEqualityUsesTheEarlierSegment` 覆盖。

解析器现在拒绝非有限、域外或不严格递增的 breakpoint。采样 `samf` 首尾段拒绝规则和已有中间段插值规则未改变，未引入 LUT 或采样表。

## 实际验证

工具链：Xcode SwiftPM，macOS 27 SDK，Swift 6。

```text
swift build --package-path Native/Packages/LUTKit -c debug        # 通过
swift build --package-path Native/Packages/LUTKit -c release      # 通过
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCMPEContractsTests    # 26 项通过
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests  # 26 项通过
git diff --check                                                     # 通过
```

定向测试日志保存在同目录 artifact 中，并包含实际命令输出和退出码。完整原生数值门禁、第三方 profile 逐码参照及所有 MPE 元素不属于本次范围，不能由这 26 项测试代替。

## 未覆盖范围

本项只关闭 `curf` breakpoint 的规范结构边界；不声称完成 ICC 全部 profile class、其他 MPE 元素、BPC、gamut mapping、ColorSync、目标软件往返、HDR/EDR 或完整发布清单。
