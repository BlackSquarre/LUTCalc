# H12 旧设置格式用途字段候选验收

日期：2026-09-25

## 范围

旧设置中的 `formats.grading` 与 `gradeOption/mlutOption` 共同决定输出格式的用途。原检查器在识别出受支持格式标题时只记录标题路径，遗漏了已参与候选判定的 `grading` 字段。本阶段只修正只读报告完整性，不开放旧设置迁移。

## 契约与实现

- 对 SPI1D、SPI3D、ILUT、OLUT、Assimilate 1D 和 VLT 的精确标题候选，要求同时报告 `formats.grading` 与对应标题路径。
- Resolve/CUBE 方言、未知格式或缺失用途字段继续保持未映射。
- `canMigrate` 仍固定为 `false`，不创建 `ProjectManifest`。

先运行新增断言，旧实现对 6 个支持格式案例均失败；随后在 `LegacySettingsInspector` 将 `formats.grading` 与格式标题一起加入 `mappedPaths`，定向 Release 契约通过。

## 验证

定向命令：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter LegacySettingsContractsTests/testExactSupportedFormatNamesExposeReadOnlyCandidates
```

结果：1 项测试通过；完整回归与三平台构建待本阶段批量入口完成后补记。

随后完整执行 `bash tools/native-validation/verify-native-release.sh`：165 项 Swift Release XCTest、旧 Node/Python 契约、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过。日志为 `/tmp/lutcalc-h12-format-mode-candidate-release-20260925.log`，SHA-256 为 `aa9f7e1d2e3257df5e44a2cf4b879e1759ecc71ee5eda188e0f0c58b2958966d`；发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2。

## 未完成项

旧设置相机身份、全部调节算法、版本迁移、格式方言和完整 H12/FULL-08 仍未完成。
