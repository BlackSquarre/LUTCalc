# `.olut` 原生文档导出阶段验收

日期：2026-09-25。范围：在既有 `.olut` 固定 4,096 点、12-bit 六列重复 RGB 解析/写出子集上，接入纯 Swift 文档导出服务；不代表 DaVinci Resolve 真实软件导入或 FULL-06 完成。

## 契约先行

新增 `OLUTServiceContractsTests.swift` 后，先执行 Release 定向测试。测试按预期在编译期失败：`FileLUTFormat` 尚无 `.olut` 成员，证明导出接线尚未存在。随后增加 `.olut` 格式枚举、独立 `FileOLUTSink`、`NativeExportService` 分派和功能草稿格式选项。

## 实现边界

- `FileOLUTSink` 使用现有 `OneDBlockSink` 和 `Double` 生成路径，固定接收 4,096 个节点。
- 校验阶段调用 `OLUTWriter`，文件以临时路径写入并检查字节数后提交；默认拒绝覆盖，已有目标被外部改写时拒绝提交，取消或失败清理临时文件。
- 导出服务仅接受单位域、输入/输出同色域的 1D 计划；跨色域、非单位域和无法由 12-bit OLUT 无损表达的计划显式失败且不留下目标文件。
- 既有格式规范只采用旧 `js/lut-davinci.js` 的 4,096 点登记与当前已验证的六列/12-bit 子集；没有引入厂商 LUT、`.labin` 或等价采样表。

## 验证

命令：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter OLUTServiceContractsTests
```

结果：2 项测试通过，0 失败。

- 文档会话生成 `.olut`，写出 4,096 行并由 `OLUTParser` 读回；中点红通道与独立 `TransformPlan` Double 计算结果的差异不超过半个 12-bit 码值加浮点容差。
- 跨色域、非单位域和非零曝光的不可表示请求均失败，目标文件不存在。

本记录只覆盖原生文档导出服务和事务边界；尚未验证 Resolve 实际导入、系统保存面板、File Provider、真机文件往返、旧 `.olut` 方言或完整格式清单。FULL-06 仍未完成，发布门槛仍需真实全量验收清单。
