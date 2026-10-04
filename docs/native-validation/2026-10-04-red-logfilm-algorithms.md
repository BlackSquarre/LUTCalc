# 2026-10-04 REDLogFilm 算法验收

## 范围与裁决

本包只处理旧清单中 `REDLogFilm` 的解析路径和 `REDWideGamutRGB` 色域身份。旧 `js/gamma.js` 明确将 REDLogFilm 注册为 `LUTGammaCineon`，参数为 `cv=1023`、`bp=95`、`wp=685`、`nGamma=0.6`、`cv2d=0.002`。原生版保存独立 RED 算法 ID，并复用已独立验收的 Cineon 参数实现；这不会把未来 RED 专用曲线与 Cineon 静默混同。

公开 REDLogFilm 路径使用 scene 反射率域；legacy 路径保留 LUTCalc 灰 `0.2` 线性域和负值 toe。公开编码对不在定义域的负值显式失败，公开解码仍保留 full-code 产生的负 scene 值，不裁剪、不延拓。`REDWideGamutRGB` 按旧源码公开原色和 D65 白点以 Double 推导矩阵：红 `(0.780308, 0.304253)`、绿 `(0.121595, 1.493994)`、蓝 `(0.095612, -0.084589)`。

本包没有启用 Epic DRAGON 的默认相机路由：现有相机使用 `DRAGONColor2`，其完整原色、白点和设备语义仍需独立资料验收。共享 Cineon 参数不构成完整 RED 相机支持证明。

## 实现与契约

- 新增 `REDLogFilmTransfer`，公开与 legacy 两个稳定身份。
- 接入 `TransformPlan`、`NativeOutputEncoder`、显式 code-unit 分类、目录、项目身份和 `LUTReferenceCLI`。
- 新增 `red.wide-gamut-rgb.v1` 色域身份和公开原色矩阵。
- 公开验证预设输出 `linearScene`，避免一档曝光后把公开 Cineon 编码强行延拓到未定义负值；legacy 预设保留旧曲线输出。
- 契约覆盖公开/legacy 分域、负值/非有限失败语义、计划路由、目录和项目字段。

独立参照脚本为 `tools/native-validation/red-logfilm-reference.py`，使用 90 位 Decimal，未读取 Swift 代码、研究 LUT 或 App 资源。

## 实际结果

证据目录：[2026-10-04-red-logfilm-contracts](artifacts/2026-10-04-red-logfilm-contracts/)。

- RED 定向契约 2 项通过；Swift Release 全量 **699 项、0 失败**，LUTFormats 的 2 项既有外部夹具跳过。
- 公开与 legacy 两个身份各生成 17³、33³、65³，共 6 个 CUBE、630,950 节点、1,892,850 通道。独立 Decimal 逐通道最大尺度化误差为 **`9.217626661950362e-14`**，门槛仍为 `2e-12`；逐网格结果见 `cube-decimal-summary.json`。
- 故意扰动节点后独立验证器退出码为 1，拒绝结果保存在 `perturbation-rejected.log`。
- macOS、generic iOS、generic iOS Simulator Release 均生成 App；三个 App 包审计和 157 项生产 Swift 源码审计通过。Simulator 日志仍记录系统 CoreSimulator 内存不足诊断，但不影响 generic 构建产物。
- 目录当前为 **62 曲线、20 色域、58 预设、66 相机身份**；`LUTCatalogChecks` 通过。

## 未覆盖

DRAGONColor/DRAGONColor2 的完整矩阵和 Epic DRAGON 默认相机、REDLogFilm 与 REDWideGamutRGB 的跨色域独立参照、RED 风格输出渲染、RED Log3G10 之外的旧风格曲线、第三方软件往返仍未完成。其余查表替代、`.labin`、HDR/OOTF、完整 ICC、LUTAnalyst、UI、真机性能和发布验收不在本包范围内。Goal 保持 active。
