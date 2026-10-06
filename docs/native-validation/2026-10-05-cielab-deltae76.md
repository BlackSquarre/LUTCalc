# 2026-10-05 CIELAB CIE 1976 Delta E 算法验收

## 范围

本轮补齐现有 CIELAB 数学范围中缺失的 CIE 1976 `Delta E*ab` 距离。实现位于 `Native/Packages/LUTKit/Sources/LUTCore/CIELAB.swift` 的 `CIELABColor.deltaE76(to:)`，只计算同一 Lab 白点和观察条件下的欧氏距离，不执行白点适应、色域映射、显示转换或项目持久化。

项目内部 `L*` 按兼容约定保存为 `0...1`，而 CIE 1976 标准距离使用 `0...100` 的 L*。实现只在距离计算中将 `Delta L*` 乘以 `100`；`a*` 和 `b*` 保持传统单位。这避免把归一化 L* 差值误当成标准 Delta E。

## 先行契约与实现

先在旧代码上加入 `CIELABContractsTests.testCIE1976DeltaEUsesEuclideanLabDistance`，Release 编译按预期失败，错误为 `CIELABColor` 没有 `deltaE76` 成员；随后新增实现并保留同一契约。实现后的命令为：

```sh
python3 tools/native-validation/probe-cielab-deltae.py | tee /tmp/lutcalc-cielab-deltae-decimal-20261005-r2.json
swift test --package-path Native/Packages/LUTKit -c debug --filter CIELABContractsTests | tee /tmp/lutcalc-cielab-deltae-debug-20261005-r3.log
swift test --package-path Native/Packages/LUTKit -c release --filter CIELABContractsTests | tee /tmp/lutcalc-cielab-deltae-release-20261005-r3.log
```

工具链为当前主机 SwiftPM/XCTest、Python 3 `decimal`（80 位精度）和仓库现有增量 `.build`。Debug 与 Release 的 `CIELABContractsTests` 均为 4 项通过、0 项失败；定向命令中的其他 XCTest target 没有选中测试。

## 独立参照与误差

独立 Decimal 参照输入为 `first=(L*=0.42,a*=12,b*=-8)`、`second=(L*=0.57,a*=3,b*=4)`。归一化 L* 差为 `-0.15`，标准 Delta L* 为 `-15.00`，完整标准差向量为 `(-15, 9, -12)`，距离为：

`21.213203435596425732025330863145471178545078130654221097650196069860987176931606`

Swift 运行值为 `21.213203435596423`，与独立 Decimal 参照的二进制 Double 舍入差低于 `1e-14`。同色比较返回精确 `0.0`。

结果包 SHA-256：

| 结果 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-cielab-deltae-decimal-20261005-r2.json` | `806e26042cb7c2314cfaebea7269d68a5e1de793ca74a120087715330d4bbfb3` |
| `/tmp/lutcalc-cielab-deltae-debug-20261005-r3.log` | `c24cda1d9f9bff7e4ac16d0e9e796c5953e13ba76cef412cfc8dd5a9e99bc2f5` |
| `/tmp/lutcalc-cielab-deltae-release-20261005-r3.log` | `16ac39b4cf99783be5adb289557a7bde2b42fa73ceb1586ca6b9839fbd583bef` |

## 未覆盖范围

- 本项只关闭 CIE 1976 Delta E 的同条件数学子集，不实现 CAM 或其他未单独验收的感知模型；CIE94 和 CIEDE2000 另见[对应验收](2026-10-05-cielab-deltae94.md)与[对应验收](2026-10-05-cielab-deltae2000.md)。
- 不改变 RGB `TransformPlan`、`ColorSpaceID`、项目 schema、ICC profile linking 或显示色彩管理；完整 CIELAB 工作流仍未完成。
- 不为负 RGB、任意 Log 值或未经白点确认的样本自动计算感知差异；调用方必须先提供同一 Lab 条件。
- 本项不影响 `9/9` `.labin`、`45/45` 直接查表、PQ OOTF、完整 HDR/EDR、LUTAnalyst 全局反求、平台验收和发布清单；Goal 保持 `active`。
