# H11 通用参数化 Gamma 阶段验收

日期：2026-09-25。范围：把旧 `LUTGammaGam` 的通用分段幂函数抽成可复用的纯 Swift `Double` 值类型，并让现有 γ1.5–γ2.6 注册曲线复用该核心。此阶段不创建任意运行时 `TransferID`，也不把参数写入项目清单；CIE L* 固定条目、HDR/OOTF、设备范围和跨色域链另行验收。

## 公式与边界

`ParameterizedGammaTransfer` 保存 `exponent`、`linearSlope`、`offset`、`linearCut` 与独立的 `encodedCut`。高段使用 `(1 + offset) × value^(1/exponent) - offset`，低段使用 `linearSlope × value`；逆函数按独立 `encodedCut` 选择高低段。这样保留了旧实现中 `params[3]` 与 `params[4]` 可以不同的边界语义。省略 `encodedCut` 时取 `linearSlope × linearCut`，仅适合该默认值与曲线实际边界一致的配置；其他配置须显式提供。

实现是解析公式，不包含厂商 LUT、`.labin` 或等价采样表。固定 γ1.5–γ2.6 已改为调用同一纯 Swift 核心，仍通过现有 LUTCalc legacy 0.2 灰度标度与 data wrapper。

## 契约与验证

先写失败契约后实现：

- 典型 γ2.2、ProPhoto 1.8 参数和 CIE L* 参数形状的正反向批量回读；
- 显式 offset、低段斜率和独立 `encodedCut`；
- 负值/超白的解析分支、非有限输入拒绝；
- 指数、斜率、offset 和切点的非法参数拒绝；
- 注册表来源、稳定 family ID `gamma.parameterized.v1`，以及现有 15 个 `LUTGammaGam` 派生目录条目来源检查。

结果：

- 定向 Release：`ParameterizedGammaContractsTests` 4 项、注册表 2 项通过；日志 `/tmp/lutcalc-param-gamma-final-targeted-20260925.log`，SHA-256 `0ee2585e7270c3d8210822ac5168f2a7a95d40cf2cc0149f6fd78e6e385bd4a9`。
- 完整 Swift Release 测试退出码 0；日志 `/tmp/lutcalc-param-gamma-full-swift-20260925.log`，SHA-256 `3d50bc899a2e79d1882e70431f559c2c697d38b0499ed114462ff3a38de20d76`。
- 原生子集静态、命令行和 40 对 33³/65³ CUBE 批量生成/独立读回退出码 0；日志 `/tmp/lutcalc-param-gamma-subset-20260925.log`，SHA-256 `3207b2aaab606ab2756fb15a045f5411b00d950997f84cd9c6af535408c2fd88`。

## 未完成边界

通用参数尚未成为可持久化的 `TransformSettings` 参数载体；当前稳定目录仍使用固定 `TransferID`。CIE L* 的固定 ID、同空间计划、独立 33³/65³ 读回、HDR/OOTF、真实设备范围、跨色域和真机验证仍未完成。该批不代表 H11、完整迁移或发布完成。
