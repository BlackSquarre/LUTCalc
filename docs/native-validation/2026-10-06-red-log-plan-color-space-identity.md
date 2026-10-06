# RED Log 计划色域身份验收

## 范围

本次只闭合 RED LogFilm 与 RED Log3G10 两个内置解析计划的身份字段，确保计划版本同时绑定输入和输出色域，避免同一 transfer 被错误复用到不同色域组合。未扩展 UI、平台或外部 LUT 范围。

## 契约与实现

先新增 `REDLogFilmContractsTests` 和 `REDLog3G10ContractsTests`，覆盖输入色域变化、输出色域变化、目录往返、边界与非有限输入，以及 legacy 公式冻结参照。旧实现定向红测共 12 条失败断言，确认问题是计划身份遗漏而非公式误差。

实现将计划版本固定为：

- `analytic-red-logfilm-v1`
- `analytic-red-log3g10-legacy-v1`

计划序列化身份现在包含 `inSpace` 与 `outSpace` 字段。旧 RED Log3G10 身份断言同步到完整值：`analytic-red-log3g10-legacy-v1:linear.scene.v1:red.log3g10.lutcalc-legacy.v1:inSpace:red.wide-gamut-rgb.v1:outSpace:red.wide-gamut-rgb.v1`。

## 实际验证

工具链：Apple Swift 6.4，swift-driver 1.168.6，arm64 macOS 27.0.0。

定向命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'REDLogFilmContractsTests|REDLog3G10ContractsTests'
```

结果：退出码 `0`，`REDLog3G10ContractsTests` 5/5、`REDLogFilmContractsTests` 3/3，共 8/8 通过。

整包命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --quiet
```

结果：退出码 `0`；LUTCore、LUTAnalysis 及其余 Release 测试通过。LUTAnalysis 汇总为 93/93，通过记录中的组合 shaper 冻结参照最大尺度化误差为 `4.440892098500626e-16`。

附加检查：`git diff --check` 退出码 `0`。

## 未覆盖范围

本记录不证明 `.labin` 替代、直接查表替代、tricubic 全根完备性、完整 ICC/HDR/OOTF、真实软件往返、平台验收或发布清单完成。相关范围继续保持未完成状态。
