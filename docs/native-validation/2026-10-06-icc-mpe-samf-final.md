# ICC MPE `samf` 末段采样曲线修复验收

## 范围

本轮只修复 `ICCMPETransform` 对 ICC.1:2022-05 `mpet`/`curf` 末段
`samf` 的边界处理。采样段的隐含首样本来自前一段在下界的输出；首段没有
该值，继续拒绝。末段没有下一个 breakpoint，按规范延伸到归一化曲线域终点
`1.0`。中间段仍使用下一个 breakpoint。所有样本先按有限 Float32 解码，执行
路径保留 Double 线性插值；没有打包 LUT、`.labin` 或厂商采样资产。

## 契约与生产改动

- 先行测试把末段合法性固定为：末段构造成功、输入 `1.0` 命中最后显式样本、
  区间中点按隐含起点和最后样本线性插值；另覆盖多样本末段在端点和区间内的
  插值，避免把最后样本错误当作内部样本。
- 生产解析器只放宽末段位置检查；首段 `samf` 仍返回 `.malformed`，样本数量、
  checked arithmetic、元素范围和非有限浮点检查保持不变。
- 该修复与现有 ICC MPE `cvst`、`matf`、`clut` 和 device-link 路由契约相容，
  不扩展未知或厂商元素。

## 实际命令与结果

工具链：Apple SwiftPM／XCTest，macOS 当前 Swift toolchain。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ICCMPEContractsTests
git diff --check
```

Release `ICCMPEContractsTests`：30 项通过，0 失败，退出码 `0`。完整输出保存于：

- `docs/native-validation/artifacts/2026-10-06-icc-mpe-samf-final/release.log`
- SHA-256：`5e9c40fbae8cf37e16a9780860f5545bdabdc7b738f7ec530838587c9e7e1a68`

## 未覆盖范围

本轮不代表完整 ICC profile linking、全部 profile class/intent、BPC、通用 gamut
mapping、ColorSync、真实第三方 profile 逐码参照或未来 MPE 元素完成。`.labin`、
直接查表替代、任意 3D LUT 全局反求和 Goal 仍未完成；Goal 保持 `active`。
