# 2026-10-03 非 UI 未完成范围核对

## 结论

本记录只核对计算、解析、任务、项目存储、文件后端、性能和发布范围；界面、布局、交互、无障碍、旋转、多窗口、Finder／Files 面板和目标软件界面往返按当前决定暂缓。Goal 继续保持 active，没有创建或伪造 `full-scope-acceptance.json`。

## 当前可执行证据

- `LUTCatalogChecks`：52 条曲线、18 个色域、48 个预设，稳定 ID、别名、来源、重复和悬空引用检查通过。
- `CameraStateContractsTests`：4 项通过；66 个稳定相机身份均保留。2026-10-03 实际默认可用性为：公开算法 34/66，旧兼容 25/66；其余分别为 32/41 个明确阻塞。相机状态独立 Decimal 核对 1,992 个值，最大相对误差 `1.436449758384103e-15`。
- `NCP0100ContractsTests`：4 项执行、0 失败、1 项可选公开实样跳过。638 字节 `0100` 只读子集可读；`NCP0100Writer` 仍显式返回 `.writeUnsupported`，不猜厂商写出语义。
- 发布证据检查退出码为 2，唯一阻塞是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

命令、日志、路由静态核对和 SHA-256 清单见 [`artifacts/2026-10-03-non-ui-audit/`](artifacts/2026-10-03-non-ui-audit/)。路线图较早阶段出现的公开 31/66、旧兼容 22/66 是历史快照；本记录的 34/66、25/66 来自当前可执行契约。

## 仍未完成的非 UI 项

### 算法与相机

- 全部旧有效曲线／色域／特殊空间的逐项算法替代、版本身份、来源和旧差异闭合仍未完成。
- 相机默认仍只覆盖已有映射；2026-10-04 Nikon Z6/Z7 的 N-Log 与 Generic Cineon 已分别按公开／旧兼容策略接入，最新计数为公开 37/66、旧兼容 28/66，见[相机传递算法验收](2026-10-04-camera-transfer-algorithms.md)。S-Log2、C-Log、RED、DJI 旧机型、Blackmagic Pocket Film 等仍需逐项公开公式或明确阻塞。
- SUP2 raw 光源／目标矩阵标题冲突、连续 EI、sensor 单位、CP IDT、camClip 辅助分析和实际高 EI shoulder 仍未闭合。已有元数据和公开曲线验收不能代替相机实测。

### HDR／显示数学

- PQ OOTF 的来源、输入单位、`Lw`／scale 语义仍存在可复现冲突，不能猜公式。
- 自动峰值、参考白、黑位、四种 HDR 显示变体、完整 PQ／HLG 限幅与裁剪统计，以及真实 HDR／EDR 设备参照仍未完成。

### ICC 与图像

- 现有 CPU 子集已覆盖部分 RGB matrix/TRC、三通道 `mft1/mft2/mAB/mBA`、PCS Lab／XYZ 和显式像素 alpha 语义；完整 profile 类型、任意通道数、其他 rendering intent、黑点补偿、gamut mapping、系统色彩管理、Core Image／Metal 等价和跨平台独立参照仍未完成。

### LUTAnalyst 与资源

- 严格单值 1D 线性／cubic 反求已接入部分项目和导出边界；后续[输入反求恢复身份验收](2026-10-03-batch-inverse-identity.md)修复了批量仅绑定插值名而遗漏有效 transfer 内容的问题。病态／多解报告、完整 TF／颜色分离、重建、方向、量化元数据和任意 3D 逆仍未完成。任意 3D 逆必须继续显式拒绝，不能用近似替代。
- 9 个内置资源、45 个直接查表项及其间接依赖的逐项算法替代或研究台账仍未闭合；不得把旧 `.labin`、厂商 LUT 或等价采样表打入 App。

### 格式与互操作

- CUBE、SPI、VLT、ILUT、OLUT、Assimilate 和部分 `.3dl` 已有纯 Swift 子集。后续[批量格式与 shaper 验收](2026-10-03-batch-format-shaper.md)已证明当前八格式默认参数的本地两曝光批量恢复、Flame 非线性 `.3dl` 完整 17³/33³/65³，并修复 shaper 快照／恢复身份遗漏。[3DL 批量 flavor 与 schema 24 验收](2026-10-03-batch-3dl-flavor.md)现已接通 Flame／Lustre／Kodak 的批量 exporter、恢复身份和项目预设，完整三网格非线性 shaper 独立逐码通过。后续[项目 inputShaper 资产验收](2026-10-04-project-input-shaper.md)现已关闭用户独立 1D 原始文件的项目持久化／重开／3DL 请求重建子集。其他设备布局、任意位宽、全格式参数／色彩计划组合、其他格式输入 shaper 写出和独立第三方互操作仍未完成。
- NCP 目前只有严格只读子集；没有足够厂商规格、机型／固件和 Nikon 软件证据前，不能实现写出。

### 文件后端、性能与发布

- 后续[2026-10-04 文件 fingerprint 稳定性验收](2026-10-04-fingerprint-stability.md)修复了路径 inode 与另行打开字节可能混用的实际竞态，并验证本地独立进程等字节替换拒绝。真实 iCloud／File Provider 授权撤销、stale 续期、跨进程 provider 目标替换、哈希后至最终替换的非协作窗口、祖先目录变化、磁盘故障矩阵、iPhone 11 后台终止恢复和 provider 生命周期仍未证明。本地 Foundation／Darwin／协调契约不等价于真实 provider 证据。
- 尚缺实体 iPhone 11 的 CPU、峰值内存、流式写出和取消延迟预算；也缺 iPad 模拟器计算基线、批量／分析／图像预算。
- 尚未完成签名、归档、公证、安装升级、渠道包审计和逐项发布验收；真实全量清单缺失，因此不能勾选 FULL 或 Goal complete。

## 下一步顺序

1. 继续补有公开公式和独立参照的曲线／色域及相机默认；保留资料冲突为研究阻塞。
2. 完成明确可证明的格式解析／写出和批量覆盖；NCP 等资料不足项只记录阻塞。
3. 继续 ICC 剩余语义与 HDR 研究，随后补真实 provider 故障矩阵。
4. 最新决定：先完成已有算法范围，再处理其余问题；UI 暂缓、真机性能追加工作按用户要求跳过，不反复请求样本。

本次核对没有改变任何 FULL-01 至 FULL-08、H01 至 H14 的完成状态。
