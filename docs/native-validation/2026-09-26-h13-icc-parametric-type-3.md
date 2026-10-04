# H13 ICC 参数曲线类型 3 CPU 阶段验收

日期：2026-09-26

## 范围

本批在既有 ICC RGB matrix/TRC CPU 子集上增加 `para` function type 3。实现仍只使用 Swift `Double`，不保存采样曲线或 LUT，不引入 Core Image、Metal、工作空间转换或隐式显示转换。

## 失败契约

先在 `ICCMatrixTRCContractsTests` 增加 `testParametricTypeThreeMatchesIndependentReferenceAndInverse`，随后执行：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests
```

实现前按预期失败：ICC `para` type 3 被 `ICCProfileValidator` 按 5 个参数读取，新增 6 参数夹具返回 `invalidProfile`。

契约要求：

- type 3 按 `Y=(aX+b)^g+c`（`X >= d`）和 `Y=fX`（`X < d`）求值；
- payload 参数顺序固定为 `g,a,b,c,d,f`，全部先解码为 `Double`；
- `g/a/f` 为正，分段逆函数按切点输出值选择高段或低段；
- type 0/1/2/4、`curv(count=1)`、矩阵和域门控语义不改变；
- 未知 `para` 类型继续严格拒绝。

## Swift Double 实现

- `ICCProfile.swift` 将 type 3 参数数量从 5 修正为规范的 6；
- `ICCMatrixTRCTransform.swift` 新增 `Curve.parametricThree`；
- 解码使用 ICC type 3 的高段/低段分支，编码使用高段切点值和 `f` 的低段逆函数；
- 构造时要求 `g > 0`、`a > 0`、`f > 0`，避免非单调或非有限逆函数；
- 既有 type 5 未知类型拒绝契约保留。

## 定向与网格结果

- `ICCMatrixTRCContractsTests`：7 项通过；新增 type 3 独立低段/高段样本和逆函数检查通过；
- 新增测试同时执行 33³ 与 65³ RGB 网格往返，最大绝对误差小于 `2e-12`；
- `LUTPreviewTests`：31 项通过，ICC 固定结构 tag 的 type 3 夹具同步为 6 参数；
- type 1/2、type 4、gamma、矩阵逆和既有 ICC metadata 契约保持通过。

## 合并 Release 与平台结果

- `swift test -c release --package-path Native/Packages/LUTKit --list-tests`：240 项列出；随后完整 Swift Release 测试通过，NCP 公开实样 1 项按既有设计跳过。
- 原生子集、7 个批量公式检查、46 对 33³/65³ CUBE 生成与独立读回通过；批量节点门槛保持 `2e-12`。
- macOS、iOS Simulator、iOS generic Release 构建及三个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-type3-native-release-20260926.log`，SHA-256：`38f3c794ad775cc014f49ac559dfe8d24abaa6f62a9206ade98a29fc62eb3b39`。
- 发布入口最终退出码为 `2`，唯一发布证据失败仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单。

## 结论边界

本批只完成 ICC `para` type 3 的可追溯 CPU 标量子段。完整 ICC tag 类型、采样型 `curv`/`mft*`/`mAB`/`mBA`、工作空间与显示转换、Core Image/Metal、HDR/EDR、整图显示、真机和发布清单仍未完成。
