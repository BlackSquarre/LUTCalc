# H12 旧设置格式序列化名称阶段验收

日期：2026-09-25

## 范围

本批次核对旧版 `js/lutformats.js:getSettings` 的真实序列化规则。该函数会从格式标题中移除括号及扩展名后写入 `formats.gradeOption` / `formats.mlutOption`，因此旧 JSON 中保存的是 `SPI 3D`、`SPI 1D`、`Assimilate 1D` 和 `Varicam 3D MLUT`，不是带 `.spi3d` 等后缀的 UI 标题。

`DaVinci Resolve 1D` 在旧 JSON 中同时代表 `.ilut` 与 `.olut`，没有额外字段区分两者。本批次拒绝把它猜测成任一原生格式。带括号扩展名的输入也保持未映射，因为那不是 `getSettings` 产生的旧文件形态。

## 契约先行

`LegacySettingsContractsTests` 先增加并验证以下契约：

- 四个无后缀、且用途分支正确的已支持名称才可生成只读格式候选；
- `DaVinci Resolve 1D` 因 `.ilut`/`.olut` 合并为同名而保持未映射；
- 格式名称出现在错误用途分支、使用未序列化的带扩展名标题或使用未知方言时，均保持未映射；
- `canMigrate` 始终为 `false`，不创建项目或改变导出行为。

## 实现

`LegacySettingsInspector.supportedFormat` 改为匹配旧 `getSettings` 实际写出的无后缀名称：

- `SPI 3D` → `spi3d`
- `SPI 1D` → `spi1d`
- `Assimilate 1D` → `lut`
- `Varicam 3D MLUT` → `vlt`

有歧义的 Resolve 1D 不登记候选，并保留原路径在 `unmappedPaths`。代码注释记录了后缀剥离和拒绝猜测的原因。

## 验证

先行失败：旧实现只识别带括号扩展名，四个真实旧序列化名称无法映射，新增的带扩展名拒绝契约也失败。

修正后定向命令：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LegacySettingsContractsTests
```

结果：`LegacySettingsContractsTests` **19 项通过，0 失败**。随后执行全包 Release Swift 测试及 `LUTProjectSessionChecks`，两者退出码均为 0；日志分别为 `/tmp/h12-format-serialized-full.log`（SHA-256 `bcea999556428a72d703471dc7f064c8f5d383fbf96158feef1c3808d6af61c3`）和 `/tmp/h12-format-serialized-session.log`（SHA-256 `1ae5c3a0114ad45990af88fe0ab395e2dc3b44b31ab43d5e057dec4598c2e7c1`）。此项只验证当前代码与契约回归，不代替全量发布验收。本批次未开放迁移入口，`canMigrate` 仍固定为 `false`。

## 未完成项

旧设置的完整输出格式方言、Resolve 两种 1D 区分字段、所有相机和调节参数、历史原生 schema 版本迁移、项目创建及 Files/File Provider 交互仍未完成；本批次不据此勾选 H12 或 FULL-08。
