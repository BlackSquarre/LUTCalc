# LUTCore 算法边界审计

## 审计范围

本次只审计已有 `LUTCore` 解析算法的边界契约，不新增传递函数身份、不引入采样表，也不改变网格、位宽或误差阈值。检查对象包括 CIELAB/Delta E、公开 CAT 矩阵、BT.1886、HLG/PQ 标量传递、ACEScc/ACEScct/ACESproxy 以及参数化伽马。

## 已闭合证据

- `CIELABContractsTests` Debug 定向运行 8 项，0 失败；覆盖 CIE 1976、CIE94、CIEDE2000、白点、分段切点、扩展 XYZ 往返和非有限输入。
- `ACESCCContractsTests` Release 定向运行 4 项，0 失败；覆盖 ACEScc 分段公式、低码值、上限、往返和非有限输入。
- 现有 `ChromaticAdaptationContractsTests` 已覆盖 9 个公开锥响应模型、D65 到 D50 独立矩阵参照、非中性样本、同白点恒等和编码往返。
- 现有 BT.1886、HLG/PQ、ACEScct、ACESproxy 和参数化伽马契约已固定公开分段公式、切点、逆变换及非法有限性边界。

## 未发现可安全新增的公式缺口

当前剩余问题不具备“公开公式 + 明确单位语义 + 独立参照 + 不改变现有范围”的最小实现条件：

1. PQ OOTF 的历史 `Lw`、输入百分比、knee 和标准 BT.2100 scene-to-display 语义仍冲突，已有研究记录明确禁止猜测或平滑跳变。
2. Legacy cubic 极大有限系数的导数判别式可能溢出；这属于数值稳定修复，需要先建立独立有限系数失败契约，再单独实现缩放求根，本轮不与其他代理修改交叉文件。
3. 完整 HDR/EDR、自动峰值、相机调节链、任意三维 LUT 全局反求、`.labin` 和直接查表替代仍缺少完整可证明契约或公开连续定义。

因此本工作包不提交猜测代码；上述项目继续保持 active，并保留现有拒绝或 `unresolved` 语义。

## 未覆盖范围

本记录不代表完整 CIELAB/CAM、完整 ICC、完整 HDR/EDR、三维 LUT 全局反求、目标软件往返、UI、真机性能或发布验收完成。Goal 继续为 `active`。

## 命令与工具链

- `swift test --package-path Native/Packages/LUTKit -c debug --filter CIELABContractsTests`：SwiftPM，Debug，8 项通过。
- `swift test --package-path Native/Packages/LUTKit -c release --filter ACESCCContractsTests`：SwiftPM，Release，4 项通过。

并行启动的其他定向测试因 SwiftPM 共享 `.build` 锁串行等待；未将等待状态误记为通过。
