# H11 CIE L* 固定曲线阶段验收

日期：2026-09-25。范围：基于 ITU-R BT.2380-0 §3.3 与 ISO 11664-4 所引用的 CIE L* 解析式，接入固定的 1D transfer、最小同色域曝光计划及研发 CUBE 批量独立读回。CIE L* 亮度曲线不等于完整 CIELAB XYZ/a*/b* 色彩空间。

## 实现与来源

原生 `CIELStarTransfer` 使用纯 Swift `Double`：线性切点 `216/24389`，编码切点 `216/2700`；高段为 `1.16 × L^(1/3) − 0.16`，低段为 `(24389/2700) × L`。反向分支使用同一精确常数。LUTCalc 兼容入口保留其 data wrapper 和 legacy 0.2 灰标度，`TransformPlan` 的场景标度转换仍显式执行 `0.9`。内置资源没有厂商 LUT、旧 `.labin` 或采样表。

固定 ID 为 `cie.l-star.v1`，目录别名 `CIE L*`，linearReference 为 `.legacyGrey02`；研发预设为 `cie.l-star-exposure-one.v1`，同空间 sRGB、Data→Data、曝光 +1。CLI `cie-lstar-exposure` 仅用于验收生成。该项不声明完整 CIELAB 色彩空间已实现。

## 契约和数值

- `CIELStarContractsTests` 2 项、注册表/计划契约 1 项通过，覆盖切点及相邻值、正反向、data wrapper、非有限输入和稳定 ID；日志 `/tmp/lutcalc-cie-lstar-redgreen-20260925.log`，SHA-256 `dcd46048c5424d68719bbe731cded409fc269d89838110521727b791c415e675`。
- 全包 Swift Release 测试通过；日志 `/tmp/lutcalc-cie-lstar-full-swift-20260925.log`，SHA-256 `7688ca28175b4de1333387ae7152432a7cb2670a1cff39a89cd0f89767fe5726`。
- 批量清单现为 21 个案例、42 对 33³/65³ CUBE 生成与独立逐节点读回。CIE L* 33³ 35,937 节点、65³ 274,625 节点，最大尺度化误差均为 `0`，门槛 `2e-12`。独立 Python 验证器读取文件轴序并重新按解析式计算，没有读取 Swift 内部样本。日志 `/tmp/lutcalc-cie-batched-cube-20260925.log`，SHA-256 `4b30f9cf9689ffef7414b9f1641212e881154b1a5edd41484e31c3637752ad81`。
- 原生子集静态与命令行契约通过，注册表为 38 曲线、13 色域、24 预设，包含相同的 42 对独立读回；日志 `/tmp/lutcalc-cie-lstar-subset-20260925.log`，SHA-256 `f27a0cae7d5bfef18adfb375691338ad34fb2b5f8b3a6fd249f06a95fb37cb36`。

## 未完成边界

任意参数 Gamma 仍没有项目参数持久化载体；完整 CIELAB 色彩空间、跨色域/适应工作流、BBC WHP283、HDR/OOTF、相机与显示设备范围、真机和发布门槛仍未完成。此阶段不勾选 H11/CORE-03/FULL-01，也不宣称完整迁移。

## 平台构建与发布状态

完整发布入口执行后，macOS、iOS Simulator、iOS generic 三个平台 Release 构建均通过，3 个实际 App 包资源审计通过；入口最终退出码 `2`，直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`。日志 `/tmp/lutcalc-cie-lstar-release-20260925.log`，SHA-256 `5ee99d4305b1ba046bf44d14eb6b9c83e8ab194b115977828fd7038c95d7bb35`。本批未运行新增曲线真机验收；用户要求设备工作最后集中处理。
