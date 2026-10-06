# TransformPlan 全局身份覆盖验收

## 范围

新增 `TransformPlanIdentityCoverageContractsTests`，枚举当前注册的 82 个 transfer 身份，分别构造 decode 与 encode 方向，检查 `planVersion` 同时包含输入／输出 `TransferID` 以及 `inSpace`/`outSpace` 两端色域。ARRI LogC scene 与 Parameterized Gamma 的必要参数也按现有构造器提供。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter TransformPlanIdentityCoverageContractsTests
swift test --package-path Native/Packages/LUTKit -c release
git diff --check
```

全局枚举契约和完整 Swift Release 均通过；完整日志为 `/tmp/lutkit-full-current-20261006-rerun.log`，SHA-256：`fc55f5b39f2f72b94ee6807ac56361ebb3d278e0671a2d0dafc4689bec0e0d49`。本项只覆盖计划身份字段，不证明参数内容指纹、完整 ICC/HDR、`.labin`、直接查表、平台或发布验收已经完成。
