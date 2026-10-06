# 2026-10-05 ACES 1.3 Reference Gamut Compression 计划与项目接线验收

## 范围

本轮只接通已经独立验收的 ACES 1.3 Reference Gamut Compression（RGC）数学内核，不扩展 UI、默认相机路由或旧调节链。RGC 运行在线性 ACES 2065-1（AP0）输入与输出之间，使用独立阶段 ID `75`；只接受 data range、无传递曲线、无相机状态和无其他耦合调节。压缩和规范闭式逆向 decompression 均保持 Swift `Double`，没有使用 LUT、`.labin` 或采样表。

## 契约与实现

- `TransformSettings` 保存可选的 `ACESReferenceGamutCompressionSettings`，其算法身份固定为 `aces.reference-gamut-compression-1.3.0`，操作固定为 `compress` 或 `decompress`。
- `TransformPlan` 在阶段 `75` 执行 RGC；非线性、非 AP0、非 data range、相机状态、白平衡／PSST、HDR/OOTF 和其他调节链均明确拒绝。
- `planVersion` 包含算法身份和操作；所有 `with...` 派生设置保留 RGC 字段，改变输入／输出传递或色域时清除不再适用的 RGC 设置。
- 项目 schema 从 `25` 升至 `26`。schema 26 保存 RGC 字段及 `algorithmVersions` 身份；schema 25 没有该字段时仍可读取，携带该字段时拒绝，不允许静默丢失。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Swift 6.4、Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ACESReferenceGamutCompressionPlanContractsTests|ACESReferenceGamutCompressionProjectContractsTests'
swift test --package-path Native/Packages/LUTKit -c release --parallel \
  --jobs "${LUTCALC_SWIFT_JOBS:-$(sysctl -n hw.logicalcpu)}" \
  --num-workers "${LUTCALC_TEST_WORKERS:-$(sysctl -n hw.logicalcpu)}"
```

- RGC 计划契约 4 项、项目 schema 契约 3 项通过，退出码 `0`。
- 当前 Swift Release 全量回归执行 `879` 项，失败 `0`，退出码 `0`。
- `Scripts/verify-native-numerics.sh` 在 Node `v22.21.0` 下退出码 `0`：66 项静态／冻结／公式检查、Node 11 项、Swift 命令行契约通过，54 个 CUBE 案例生成和独立读回通过。
- 首次全量回归发现 5 个旧迁移断言仍期望 schema `25`；只将断言更新为当前 schema `26`／`ProjectManifest.currentSchema`，没有改变迁移逻辑。修复后定向和全量回归均通过。
- 本轮未执行 macOS、iOS Simulator、iOS device 三目标 Release 构建；这些构建与 App 包审计继续属于平台／发布验收，不能由 SwiftPM 和数值门禁替代。

结果包：`docs/native-validation/artifacts/2026-10-05-aces-rgc-plan/`。

- `plan-project-release.log`：SHA-256 `a792c06b053c388d5ce1017302a7702441f19db464a78039c584d5759d459ae5`
- `full-swift-release.log`：SHA-256 `072075277414ddfdf43516577457202fdb02a2dce7c52f2110e7a8cd6f788a14`
- 两个退出码文件内容均为 `0`，SHA-256 均为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `native-numerics-gate.log`：SHA-256 `205c18bc1c54156bd62ec1e3e03784b472596365116d29c1167b4ad0bef2ed22`
- `native-numerics-gate.exitcode`：`0`，SHA-256 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

## 未覆盖范围

本轮关闭 RGC 的计划阶段、执行、快照字段和 schema 26 严格持久化子集；不代表完整 ACES 工作流、默认相机路由、UI、真实第三方软件逐码往返或旧调节链完成。RGC 仍只允许显式线性 AP0 路由，不自动插入任何相机或显示转换。

9 个 `.labin` 资源、45 个直接查表注册、完整 ICC、HDR/EDR/PQ OOTF、白平衡／PSST、LUTAnalyst 任意三维全局反求、其余资料阻塞、平台／文稿／File Provider 验收和发布全量清单仍未完成。Goal 保持 `active`。
