# 旧 S-Log3 基线跨 Node 运行时验收

日期：2026-09-24。状态：验证入口已恢复可重复；冻结夹具未改写，不能据此宣称完整迁移或发布通过。

## 问题与边界

`bash tools/native-validation/verify-native-release.sh` 的原生子集前置检查在 `generate-slog3-legacy-baseline.js --check` 失败。当前 `js/gamma.js` 的 SHA-256 仍为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`，与 `tests/fixtures/native-contracts/slog3-legacy-reference.json` 中冻结的 `sourceSHA256` 一致；失败不是旧源码被修改，也不是冻结预期需要更新。

逐字节拦截生成结果后确认，Node 22.21.0 与冻结 JSON 完全一致；本机默认 Node 26.7.0 的 `Math.log`/`Math.pow` 舍入在 309 个深层数值上产生跨运行时差异，最大绝对差异 `7.105427357601002e-15`，最大相对差异 `4.287963415941607e-16`。这些差异只出现在重新计算的 Double 文本表示中，属于有限 ULP 舍入差异。

## 修复与契约

`tools/native-validation/generate-slog3-legacy-baseline.js` 仍优先要求冻结 JSON 字节完全一致。字节不同才进入结构化核验：

- `sourceSHA256` 必须与当前 `js/gamma.js` 完全相同；
- 对象键、数组长度、字符串及非数值字段必须完全相同；
- 数值使用相对门槛 `8 * Number.EPSILON`（`1.7763568394002505e-15`），超过即失败；
- 检查输出最大相对差异和路径，便于发现真实公式或输入变化。

该门槛只处理已观察到的同一 JS 源码跨 Node 引擎舍入，不改写冻结 JSON、不降低 Swift Double 精度、不替代独立参照。

## 实际验证

```text
/Users/lingru/.nvm/versions/node/v22.21.0/bin/node tools/native-validation/generate-slog3-legacy-baseline.js --check
  退出码 0；冻结 JSON 字节一致。

node tools/native-validation/generate-slog3-legacy-baseline.js --check
  退出码 0；报告 309 个跨运行时数值舍入差异，最大相对差异
  4.287963415941607e-16，低于 1.7763568394002505e-15 门槛。

node --check tools/native-validation/generate-slog3-legacy-baseline.js
  退出码 0。

node --test tests/slog3-legacy-baseline.test.js
  退出码 0；2 项契约通过，确认当前运行时可接受，且源码哈希、数值、结构漂移都会拒绝。

/Users/lingru/.nvm/versions/node/v22.21.0/bin/node --test tests/slog3-legacy-baseline.test.js
  退出码 0；同一组契约在 Node 22 通过。
```

本记录只覆盖旧 S-Log3 冻结基线的验证入口；三平台构建、真机 SPI3D 导出和发布清单仍需由完整入口分别验证。
