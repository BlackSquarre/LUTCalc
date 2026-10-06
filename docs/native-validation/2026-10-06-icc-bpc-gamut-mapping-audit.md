# ICC BPC 与 gamut mapping 公开子集审计

## 审计结论

本轮没有新增生产代码。现有 linking 边界已经是正确的保守行为：

- `ICCMatrixTRCProfileLink` 只实现 relative/absolute colorimetric，明确拒绝 perceptual 与 saturation，不从 `bkpt`、`wtpt` 或其他头部字段推导黑点补偿或色域映射。
- `ICCLUTProfileLink` 只执行 profile 自己声明的 A2B/B2A 标签。perceptual 和 saturation 的映射由 profile 提供的 LUT 数据承载；执行器不凭空生成另一个映射。
- `ICCDeviceLinkTransform` 使用 device-link 头部声明的 intent 和单个 `A2B0` 设备到设备链，不插入额外 BPC 或 gamut mapping 阶段。

## 为什么没有可安全新增的公式

ICC rendering intent 定义了语义类别，但没有给 BPC 提供一个仅由通用 profile 头字段决定的唯一数值算法。BPC 是 CMM 策略，需要明确黑点来源、目标黑点、媒体相对/绝对单位和压缩模型；仅存在 `bkpt` tag 不能确定这些选择。

同样，perceptual 与 saturation 的 gamut mapping 结果由对应 A2B/B2A 测量或厂商建模的 transform 记录。标准没有一个可以脱离 profile transform 的通用逐点公式。自行加入 clip、chroma compression 或黑点平移会改变用户 profile 意图，且没有独立参照可验证。

因此显式拒绝未实现的 matrix/TRC intent，或执行用户 profile 已提供的 LUT，是比猜测策略更强的契约边界。本审计没有把 `bkpt` 解析、BPC 开关、gamut mapping 算法或 ColorSync 行为接入生产路径。

## 验证命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter 'ICCMatrixTRCContractsTests|ICCLUTProfileLinkContractsTests'
swift test --package-path Native/Packages/LUTKit -c release --filter 'ICCMatrixTRCContractsTests|ICCLUTProfileLinkContractsTests'
git diff --check
```

- Debug：`ICCLUTProfileLinkContractsTests` 10 项、`ICCMatrixTRCContractsTests` 25 项通过。
- Release：同样 10 + 25 项通过。
- `git diff --check`：通过。

## 研究阻塞

仍缺少公开、唯一、可复现且有独立逐码参照的 BPC 算法，以及脱离具体 A2B/B2A transform 的通用 gamut mapping 算法。完整 ICC、BPC、gamut mapping、ColorSync 和第三方 profile 逐码参照继续未完成；Goal 保持 `active`。

## 本轮复核（2026-10-06）

本轮重新核对了现有 `ICCMatrixTRCProfileLink`、`ICCLUTProfileLink`、`ICCProfileValidator` 和对应契约。验证命令为：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'ICCMatrixTRCContractsTests|ICCLUTProfileLinkContractsTests' > /tmp/icc-bpc-gamut-release-20261006.log 2>&1
git diff --check
shasum -a 256 /tmp/icc-bpc-gamut-release-20261006.log
```

结果：退出码 `0`；`ICCMatrixTRCContractsTests` 25/25、`ICCLUTProfileLinkContractsTests` 10/10 通过；总计 35/35 通过。日志 SHA-256 为 `e221b9a48f5c7cebe6dffc5f79cf2e45acd8fa5ea6fe7a16ffd2696b801a47ff`。

复核所依据的公开资料边界：ICC.1:2022-05 对四种 rendering intent 的定义，以及 `bkpt`、`wtpt` 和 A2B/B2A tag 的结构描述。该规范定义 profile 数据和 intent 语义，但没有规定一个仅由 `bkpt`/`wtpt` 推导的 BPC 中间压缩曲线；perceptual/saturation 的具体映射仍由 profile 所提供的 transform 或 CMM 策略决定。当前代码只执行已验证的 profile transform，并对 matrix/TRC 的 perceptual/saturation 请求显式拒绝。

因此本轮没有新增生产代码，也没有把线性平移、clip、chroma compression 或任意幂函数注册为 ICC 算法。`docs/native-validation/2026-10-06-icc-bpc-nonunique-minimal-repro.md` 的三条端点相同而中间值不同的复现仍成立；在获得明确的 CMM 版本、算法来源和独立逐码参照前，BPC 与通用 gamut mapping 保持研究阻塞。
