# 2026-10-05 CIELAB CIE94 算法验收

## 范围

本轮补齐 CIELAB 数学范围中的 CIE94 距离。实现位于 `Native/Packages/LUTKit/Sources/LUTCore/CIELAB.swift` 的 `CIELABColor.deltaE94(to:application:)`，依据 CIE 116-1995 的 CIE94 定义计算。两种颜色必须来自相同的 Lab 白点和观察条件；实现不做白点适应、色域映射、裁切或显示转换。

项目内部 `L*` 保存为 `0...1`，实现只在 CIE94 内部转换为标准 `0...100`；`a*` 与 `b*` 保持传统单位。图形艺术和纺织应用权重作为明确的算法枚举保存，不接入 RGB `TransformPlan`、ICC 路由或项目 schema。

## 先行契约与实现

契约覆盖 CIE94 公开样例、图形艺术／纺织权重差异、零色度端点和有限性。先在旧实现上加入 `deltaE94` 调用，编译因缺少成员失败；随后加入 Swift `Double` 实现。实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter CIELABContractsTests | tee /tmp/lutcalc-cielab-deltae94-debug-20261005.log
python3 tools/native-validation/probe-cielab-deltae94.py | tee /tmp/lutcalc-cielab-deltae94-decimal-20261005.json
swift test --package-path Native/Packages/LUTKit -c release --filter CIELABContractsTests | tee /tmp/lutcalc-cielab-deltae94-release-20261005.log
```

工具链为 Xcode 27.0（27A266a）、Swift 6.4、Apple Silicon macOS、Python 3 `decimal` 90 位精度。Debug／Release 定向 `CIELABContractsTests` 均为 8 项通过、0 项失败。

## 独立参照与误差

独立脚本没有调用 Swift 或旧 JavaScript，使用 90 位 `Decimal` 重算平方根、色度差和色相差平方。样例输入为 `Lab1=(50,2.6772,-79.7751)`、`Lab2=(50,0,-82.7485)`：

| 应用 | Decimal 参照 | Swift 契约值 |
| --- | ---: | ---: |
| 图形艺术 | `1.3950388678587343803368943577...` | `1.3950388678587375` |
| 纺织 | `1.4230462054212797490972717842...` | `1.4230462054212831` |

最大绝对差约 `3.3e-15`，契约门槛为 `1e-14`；标准公开样例数值也落在相同结果。参照结果 SHA-256：

```text
/tmp/lutcalc-cielab-deltae94-decimal-20261005.json
```

Debug 日志和 Release 日志在结果包中保存；对应 SHA-256 分别为 `47dc9a7025947d591494bafd3ec68e13220fa318506b1ae824a4d46eaeb7c446` 和 `49c687acc86e865a2bbd199d9f26097ba6720947b1282670ce63a68d3c102fb6`。独立参照文件 SHA-256 为 `a05045f7b7d27393b7c5e2178ea81dad45d56ac38159110a1c7a0a2f16ffc5e3`。

快速验证结果包中的 `full-fast.log` SHA-256 为 `62327258bbb8ea84a802b40425d76dbd9394469f7e9499b296e74f9ed94d5771`；实际 Swift Release 832 项、Node 11 项均通过。

## 未覆盖范围

- 只关闭同一 Lab 白点和观察条件下的 CIE94 图形艺术／纺织数学子集，不实现 CMC、CAM、色貌模型或完整 CIELAB 工作流。
- 不接入 RGB 主计划、ICC rendering intent、项目存储、显示管理、HDR/EDR 或 UI。
- 不为负 RGB、任意 Log 值或白点不一致的样本自动推断感知差异；调用方必须先完成条件一致性确认。
- `9/9` `.labin`、`45/45` 直接查表、PQ OOTF、完整 HDR/ICC、LUTAnalyst 全局反求、平台验收、签名发布和 `full-scope-acceptance.json` 仍未完成，Goal 保持 `active`。
