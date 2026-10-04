# 2026-10-04 项目 inputShaper 资产与生成请求验收

## 结论与范围

关闭此前台账中的“项目 shaper 资产”持久化缺口：用户主动导入的独立 1D 曲线可作为 `.lutcalc` 自包含资产保存，磁盘重开后重建既有线性输入采样器，传入单项请求、曝光批量和 3DL exporter。新增 schema 25、`ProjectInputShaperSettings` 和独立 `inputShaper` 资产角色；算法身份为 `native.project-input-shaper-linear.v1`。

本包没有修改 UI、Double 内核、网格、插值、10／12 位格式或 `2e-12` 门槛。合成曲线只位于测试和验收目录，没有打入 App。完整 H/FULL、真实 provider、设备、性能、签名与整体 Goal 均未完成，Goal 继续 active。

## 契约先行与失败记录

先写九项项目契约，再运行旧生产代码。首轮 `red.log` 退出 1，包含缺失的存储 API／清单字段／资产角色，也包含测试代码 `.clamp` 名称和复杂表达式编译问题；修正测试后实现。此日志是编译红灯，不能当成九项行为测试已执行。

初版 Debug 九项通过。随后补第十项 EditorSession 保存／快照契约：两次测试编译诊断保留在 `editor-red.log`／`debug-final.log`；修正遗漏 `try` 后，Debug 和 Release 各执行十项，均有一次 `invalidPackage` 失败，日志 `debug-final-retry.log`／`release.log` 保留。契约在原子替换后使用惰性 FileWrapper 读取；改为明确 `.immediate` 后，定向一项和最终两套十项均通过。EditorSession 同时统一通过文稿后端重建请求，避免另外维护一条遗漏输入资产的快照路径。

`wrapper-diagnostic.log` 是本轮诊断命令错误调用目录 wrapper 的 `regularFileContents` 导致异常、退出 134；不是 App 崩溃证据。修正诊断按文件类型读取后退出 0，保留原始失败和安全输出，不删除失败记录。

## 项目与请求契约

- 原始文件字节保留，资产 SHA-256 与清单一致。shaper 角色独立于既有 user LUT，不被隐式当成输出后置 LUT；允许与用户后置 LUT 共存。
- 只接受独立 1D 曲线，不从任意 3D／组合 LUT 猜测输入曲线。原始字节重新解析并与传入对象核对，缺失原始数据、内容不符、重复 shaper 资产、错误维度拒绝。外部源文件删除后，项目仍能重建请求。
- 清单载荷仅有 `assetPath`／`algorithm`；未知、重复、缺失／错配身份、非 shaper 角色、悬空路径和多份同角色资产拒绝。shaper 与输入反求同时启用拒绝，失败不修改文稿历史或资产。
- 原有 schema 1–24 不得偷带载荷、算法版本或新角色。合法旧项目迁移为 shaper nil；测试构造合法 schema 24 项目实际写盘后读取，源 manifest 字节保持。该夹具是合成旧 schema 项目，不冒充历史用户文稿。
- 激活／停用使用原编辑历史，支持撤销／重做；停用保留用户原始资产。预设、LogC、相机、参数 Gamma、后置阶段、输入反求设置和批量预设的后端重建保留 shaper 字段。静态复制路径与契约一起核对，没有验收旧 UI 控件。
- 请求冻结用户曲线的域和全部 Double 样本；非单位域、非等通道及负零保留，沿用已有线性采样器。3DL 无法表示的域／通道、节点数或码值继续明确拒绝，不重新采样／量化来掩盖不兼容。其他七种 exporter 遇到 inputShaper 在创建输出之前拒绝。
- EditorSession 对已保存项目按 `.immediate` 读取完整资产，通过 `LUTProjectDocument` 相同验证与请求重建入口；设置编辑和保存后保留字段。此为后端契约，不构成窗口、Finder 或 UI 验收。

## 独立数值与格式核对

最终 Debug／Release 每套各生成 18 个实际 3DL 文件，覆盖 Flame／Lustre／Kodak、完整 17³／33³／65³ 和 -1／0 两个曝光。每套 5,678,550 个通道，由 [`verify-project-input-shaper.py`](../../tools/native-validation/verify-project-input-shaper.py) 独立读取项目 JSON、原始 CUBE 文本和 3DL 磁盘行。

参照以 Fraction 计算 `round(1023*x²)/1023` 输入及曝光，再按原 12 位格式计算输出码；检查输入 header、蓝轴最快行序、Lustre Mesh／footer、角色／资产 SHA、每个输出整数。两套全部逐码一致，量化参照最大误差 0；原 `2e-12` 门槛不变。格式本身的最大输出量化误差单独记录为 `0.0001221001221001221`，不冒称浮点计算精度提高。

## 实际回归与构建

- 最终 Debug／Release 定向各十项，0 失败，退出 0。
- 完整 Swift Release `--no-parallel`：664 项、0 失败、2 项既有 `.labin`／NCP 可选外部夹具跳过，退出 0。八个 bundle 计数保存于 `results.json`。
- 当前源码 macOS、iOS generic、iOS Simulator 三平台未签名 Release 均 `BUILD SUCCEEDED`，退出 0。三个实际 App 包资源审计与 151 个生产 Swift 源文件审计通过。
- 构建日志包含既有 AppIntents metadata extraction skipped 警告，未声明该可选依赖；没有将未签名构建当成可发布产物。
- 发布证据检查退出 2：真实 `docs/native-validation/full-scope-acceptance.json` 缺失，未创建或伪造。

## 复现与结果包

工作目录 `/Users/lingru/claude/LUTCalc`。本轮实际 Xcode 27.0（27A266a）、Swift 6.4、SDK 27.0、macOS 27.0 arm64、Python 3.14.6。命令、失败／成功日志、项目和 3DL、独立结果、源文件修改前／后快照、App 与源码 SHA-256 清单保存在 [`artifacts/2026-10-04-project-input-shaper/`](artifacts/2026-10-04-project-input-shaper/)。

```sh
LUTCALC_PROJECT_SHAPER_ARTIFACT_DIR="$PWD/新证据目录" swift test -c release --package-path Native/Packages/LUTKit --filter ProjectInputShaperContractsTests
python3 tools/native-validation/verify-project-input-shaper.py 新证据目录 --output 新结果.json
swift test -c release --package-path Native/Packages/LUTKit --no-parallel
```

重跑使用新的证据目录；具体实际目录、命令和退出码以 `commands.json` 为准。

## 未覆盖范围

本包不证明其他设备布局、任意位宽／参数组合、其他格式的输入 shaper 写出、NCP 写出、完整 LUTAnalyst、第三方软件解释、provider 授权撤销／stale／替换、目录竞态、磁盘故障、后台终止恢复、iPhone 11／iPad 计算性能、签名公证与发布。UI 继续暂缓；本包没有新增设备操作或完整范围清单。
