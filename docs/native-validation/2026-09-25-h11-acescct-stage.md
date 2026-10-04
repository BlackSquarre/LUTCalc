# H11 ACEScct 官方公式阶段验收

日期：2026-09-25。状态：**ACEScct 官方标量、AP1 身份和同色域最小曝光计划的本地数值验证通过；H11、CORE-03、完整 ACES 交互和发布验收仍未完成。**

## 来源与边界

- [ACEScct Specification](https://docs.acescentral.com/encodings/acescct/)，本地 `research/colour/2026-09-23/pages/acescct.html`，SHA-256 `6bb3474f49b9748c24c7c6ba55e1c20df6b756c8b9394f1714d5e31b15c2ebd4`。
- 独立来源、ACES 官方实现版本和规范/历史 CTL 差异见[ACEScct 研究记录](2026-09-25-acescct-reference-research.md)。
- 规范给出 AP1 原色 `(0.713,0.293) / (0.165,0.830) / (0.128,0.044)`、D60 白点 `(0.32168,0.33767)`，以及线性 AP1 与 ACEScct 的分段公式。Swift 运行时只包含解析常数和原色，不打包规范网页、厂商 LUT 或采样表。
- 本段接入稳定 ID `aces.cct.v1`、色域 ID `aces.ap1.v1` 和研发预设 `aces.acescct-exposure-one.v1`。AP0↔AP1 的一般矩阵能力沿用现有解析原色计算；本段数值计划使用同 AP1 空间，未宣称完整 AP0/外部 ACES 管线已完成。

## 契约先行与实现

先写 `ACESCCTContractsTests` 的公开分段点、负值线性段、非有限输入、上限处理和同空间 Double 曝光计划。首次 Release 编译因 `ACESCCTTransfer`、`TransferID.acesCCT` 和 `ColorSpaceID.acesAP1` 缺失而失败，错误见 `/tmp/lutcalc-acescct-contract-red-20260925.log`。随后加入 `ACESCCTTransfer.swift`、AP1 原色、计划分支、目录登记及 CLI `acescct-exposure` 入口。

独立 Python 读回器使用 80 位 `Decimal`，按输入 Double 网格值计算“解码→曝光 +1→编码”，逐行检查 CUBE 结构、有限值、索引顺序和误差；门槛预先保持 `scaledError <= 2e-12`。该检查已加入集中批量入口。

## 实际结果

| 检查 | 结果 |
| --- | --- |
| 首次失败契约 | 缺少 ACEScct 运行时接口和稳定 ID，预期编译失败 |
| 定向契约 | ACEScct 与目录契约合计 8 项通过，0 失败 |
| 当前 Swift Package 测试 | `swift test --list-tests` 列出 129 项；Release 全包通过，0 失败 |
| 33³ CUBE 独立全节点 | 35,937 节点，最大尺度化误差 `1.1102230246251565e-16`，RMS `5.166624538350708e-17` |
| 65³ CUBE 独立全节点 | 274,625 节点，最大尺度化误差 `1.1102230246251565e-16`，RMS `4.81322947386144e-17` |
| 集中子集入口 | 退出码 0；F-Log2、ACEScct 及既有曲线、格式、项目和预览契约均通过 |

关键源码 SHA-256：`ACESCCTTransfer.swift` 为 `31d79f080a4177d565a0e9e563c1bb7fa1365a067cb0341eb1d49bc5239104a9`；独立读回器为 `f2044db63f8242147cd35de9cc011cac146835d62e141c999b803b5c7ce3d171`。真机和发布门槛不由本段本地结果替代，仍按总路线图分别验收。
