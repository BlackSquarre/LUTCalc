# H13 ICC tag directory 结构校验阶段验收

日期：2026-09-25。状态：在 ICC 原始字节校验子集上继续增加 tag directory 结构检查；不等同于完整 ICC tag 语义解析或显示色彩管理。

## 先失败的契约

在已有 ICC 头部契约上增加：

- 读取 ICC header 的 tag count；
- 读取每个 12 字节 tag record 的四字节签名、偏移和长度；
- 拒绝 tag 表越界、tag 数据越界和重复签名；
- 对最小有效 `desc` tag 和越界偏移分别给出通过与拒绝证据。

定向 Release 编译先按预期失败，原因是 `ICCProfileValidation` 尚无 `tagCount` 与 `tagSignatures`。失败日志：`/tmp/lutcalc-h13-icc-tags-red-20260925.log`；SHA-256：`1576bbd77a341425dcf4c5a153deb3ba2b4536ccf470a12cdc279f89b318a2be`。

## 实现与边界

- `ICCProfileValidator` 现在校验最多 4096 条 tag record 的表边界、签名、偏移/长度和重复签名。
- `PreviewImage` 原始 profile 资料继续保存 SHA-256 和头部/目录摘要；没有执行 tag 类型解码、曲线评估或 ICC 颜色转换。
- 现有研发 sRGB PNG profile 的实际 tag directory 通过；无嵌入 PNG 仍保持 `sourceICCUnverified`。

## 验证

- `PreviewContractsTests`：4 项通过，包含最小 tag 表和越界拒绝。
- `LUTImageChecks`：嵌入 ICC 原始字节、头部及 tag directory 校验通过；PNG/TIFF/JPEG、方向、alpha 和资源边界继续通过。
- 集中 Release 回归：155 项 Swift 测试通过，0 失败；旧 Node/Python 契约、33³/65³ 逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过。

完整日志：`/tmp/lutcalc-h13-icc-tags-release-20260925.log`；SHA-256：`592c27a98ac2326ef1ee21a71c21792889038b2caea729c47c16ceedd2ab815e`。

发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2。tag payload 语义、显示空间转换、Core Image、HDR/EDR、整图显示、双端真机和 Files 交互仍未完成。
