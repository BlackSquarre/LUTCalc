# I-Log 与 V-Log 计划身份回归验收

## 背景

全包 Release 回归发现 I-Log 与 V-Log 计划身份契约仍期待旧的短字符串，而当前实现已经把输入／输出色域以 `inSpace` 与 `outSpace` 明确写入身份。该差异属于测试契约落后，不是计算数值变化。

## 修复与验证

更新 `ILogContractsTests` 与 `VLogPlanIdentityContractsTests` 的期望字符串，使其与 `TransformPlan` 当前身份规范一致。I-Log、V-Log 定向 Release 测试随后通过。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ILogContractsTests|VLogPlanIdentityContractsTests'
swift test --package-path Native/Packages/LUTKit -c release
git diff --check
```

完整 Release 日志：`/tmp/lutkit-full-current-20261006-rerun.log`，退出码 `0`；LUTCore、LUTCatalog、LUTAnalysis、LUTPreview、LUTSharedUI 等测试目标全部通过。该记录只确认本次身份契约回归已修复，不关闭全局平台、完整 ICC/HDR、`.labin`、直接查表或发布验收范围。
