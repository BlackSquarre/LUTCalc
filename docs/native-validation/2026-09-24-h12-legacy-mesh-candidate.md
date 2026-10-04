# H12 旧设置网格候选映射阶段验收

日期：2026-09-24。范围：为旧版 `.lutcalc` 单文件只读检查补充可追溯的 3D 网格候选字段；不开放旧项目转换，也不宣称 FULL-08 完成。

## 结果

- 在 `lutBox.legalIn/legalOut` 均为严格布尔值的现有候选报告中，仅当 `version` 为已识别的 `v4.09`/`v4.10`、`lutBox.oneD` 严格为布尔 `false`、且 `meshSize` 为整数 `17`、`33` 或 `65` 时，报告 `mappedSettings.cubeSize`，并将 `lutBox.oneD` 与 `lutBox.meshSize` 列入已映射路径。
- 1D 尺寸、缺少 `oneD`、布尔/数字类型混用、非整数或未支持尺寸保持未映射；`canMigrate` 继续固定为 `false`。
- 范围字段仍只接受严格布尔值；未知字段和未证明的曲线、调节、格式、相机设置仍报告为未映射，不以当前默认值替代。

## 契约验证

先新增 3D 网格映射和拒绝用例，首次运行因 `LegacyMappedSettings` 尚无 `cubeSize` 字段而失败；日志：`/tmp/lutcalc-h12-legacy-mesh-red-20260924.log`。补充字段与严格整数/布尔门控后，
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release --filter LegacySettingsContractsTests`
通过 6 项、0 失败；日志：`/tmp/lutcalc-h12-legacy-mesh-green-20260924.log`。

完整发布入口首次执行时，旧 `LUTProjectSessionChecks` 仍要求 `meshSize` 未映射，按预期报错退出 1。将其 v4.09/3D/33 夹具的期望改为新候选报告后，Release 集成入口通过；日志：`/tmp/lutcalc-h12-legacy-mesh-session-green-20260924.log`。完整发布入口需在最终源码上再次运行。

## 未完成

该候选映射仍是只读报告，未创建 `ProjectManifest`，未执行旧设置迁移。其余影响输出的旧字段、版本迁移、iOS Files/File Provider 及双端保存交互仍未验收；H12、FULL-08 保持未勾选。
