# 2026-10-02 SDR 显示转换非 UI 阶段验收

## 范围与结论边界

本工作包实现生成管线阶段 16 的 SDR Display Colourspace Converter、主／次级 Gamut Limiter 的显示依赖、schema 13 项目保存及文稿后端。不新增界面，也不执行设备、Finder、Files、旋转或无障碍交互。用户要求的 UI 暂缓继续有效。

已覆盖旧列表中的 23 条不同 SDR 曲线与 7 个显示色域。DCI-P3 的 DCI、D60、D65 条目共用一条 gamma 2.6 曲线，但有独立白点。四个 HDR/OOTF 显示变体及完整旧调节链尚未完成，FULL-04、H06/H12/H14 保持未勾选，Goal **active**。

## 冻结契约与实现

- 算法身份：`lutcalc.display-sdr-decode-matrix-encode.v1`；不可变 `DisplayConversionSettings` 保存 enabled、基础／目标曲线和基础／目标色域。
- 23 曲线：Rec.709、Rec.2020 12-bit、sRGB、DCI gamma 2.6、Scene Linear IRE、Scene Reflectance、CIE L*、BBC 0.4／0.5／0.6、ProPhoto，以及 gamma 1.5–2.6。
- 7 色域：Rec.709、Rec.2020、sRGB、P3 DCI、P3 D60、P3 D65、ProPhoto D50。矩阵从原色和白点推导，以固定 CAT02／SGamut3cine 两步组成，独立于主计划所选 CAT；不搬旧矩阵数组或 LUT。P3 trace 保存独立 DisplayGamut，不伪报主目录已有 P3 或误标 Rec.2020。
- 顺序为基础曲线解码→3D 矩阵→目标曲线编码。基础曲线由用户明确选择，不自动换成主输出 transfer。输入先按当前 `OutputCodeUnitPolicy` carrier 换到 Legal，结果恢复同一 carrier，再进入阶段 17／19。既有 partial v1 仅保留历史单位行为，不给新正确性声明。
- 旧 1D `displayOut(buff)` 跳过矩阵，只转换曲线；即使选不同显示色域，也不改为 3D 灰轴采样。3D `displayOut(buff,{rgb:true})` 才做矩阵。
- BBC buffer 逆函数的严格 `>` 分支、ProPhoto 原幂式得到的 Double 阈值和分段邻域均保留；负值／超白不额外裁剪，非有限或溢出定位阶段 16。
- 阶段 16 位于 Black Gamma 后、Post Gamma Gamut Limiter 前；后者的次级线性数据也经过同样 Knee／编码→黑白电平→Black Gamma→显示转换。黑白电平和 Black Gamma 默认锚点不加入显示转换；限制器仍用旧主输出色域 Y 系数。
- schema 13 才允许 `displayConversion`。原生 schema 1–12 缺字段明确迁移为 nil，schema 12 的 complete v2 单位身份保留；schema 1–11 继续既有 partial v1 迁移。字段、算法身份、disabled、快照、撤销／重做和 gamma 后端编辑保留；未知键／曲线／色域／版本、身份错配和旧 schema 偷带字段拒绝。读取不改写源文件。

实现位于 `LegacyDisplayConversion.swift`、`TransformPlan.swift`、`ProjectManifest.swift`；`LUTProjectDocument.swift` 只增加后端字段保留。

## 契约先行与实际失败

1. 核心先行契约最初因类型尚未实现失败，见 `contract-red.log`。
2. 第一次核心 Debug 编译成功，旧参照和阶段定位通过，但独立夹具仍在生成，报文件不存在；见 `debug-core.log`。保留失败，等待原任务实际退出 0 后再复跑，没有重复启动该任务。
3. 项目／文稿契约在 schema 12 上先失败：`unknownField("settings.displayConversion")`、版本缺失与旧 schema 字段接纳；见 `storage-contract-red.log`。随后实现 schema 13 和严格校验。
4. 第一轮存储复跑还暴露测试夹具使用两个不同 UUID，编辑会话正确返回 `projectIdentityMismatch`；只修正测试项目 ID，保留 `debug-storage.log`。数值门槛、样本域、网格和产品计算未改。
5. 最终定向 Debug 执行 **7 项、0 失败**：核心 4、项目 1、文稿后端 2，见 `debug-verified.log`。

## 独立参照与实际旧执行链

- `generate-display-conversion-legacy-reference.js` 实际调用旧 `setDisplay/displayOut`，冻结 627 组：23×23 曲线组合与 49 色域组合的 1D／3D；8 类基础 RGB、固定种子 RGB、分段点及相邻 Double 共 80,469 通道。旧源码 SHA-256 写入夹具。
- `generate-display-conversion-independent-reference.py` 使用 70 位 Decimal 的独立曲线方程和有理数原色／白点／CAT02，直接推导源→目标矩阵，不读取旧矩阵或旧数值。578 组、41,616 通道；另覆盖两套配置（Rec.2020→P3 DCI、ProPhoto D50→P3 D60）的 33³／65³ 完整网格，域为 `[-0.5,2]`，共 1,863,372 通道。
- `generate-display-conversion-export-reference.py` 独立 70 位 Decimal 生成 1024 点 Rec.709→Scene Reflectance 的 1D 参照，明确跳过矩阵。
- `generate-display-conversion-legacy-pipeline.js` 实际旧 DLog2 解码→色域／曝光→CDL→Multitone→Highlight Gamut→SDR→Gamut Limiter 阶段 12→Knee→黑白电平→Black Gamma→Display→Gamut Limiter 阶段 17→Data 输出，两模式各 17³。Display 选择 Rec.709／Rec.2020→sRGB／P3 D60，包含非恒等曲线和白点转换、Post Gamma 次级同时保护。最终旧 clamp 明确关闭，只证明本子链，不代替完整限幅政策。
- 研究脚本与夹具只用于研发，未声明 Swift Package resources，未进入 App 包。

### Release 实际尺度化误差

定义为 `abs(actual-reference)/max(1,abs(reference))`，全部门槛保持 `2e-12`。

| 集合 | 通道数 | 最大 | RMS | P99 |
| --- | ---: | ---: | ---: | ---: |
| 实际旧显示曲线／矩阵／1D | 80,469 | `7.021544003521508e-14` | `5.42976940116626e-16` | `6.242312513727045e-16` |
| 独立 Decimal | 41,616 | `8.43769498715119e-15` | `1.5781552026781373e-16` | `4.589668867524481e-16` |
| 两配置完整 33³／65³ | 1,863,372 | `3.1086244689504383e-15` | `4.142769663831941e-16` | `1.3944335278425037e-15` |
| 旧 Linear 限制组合 17³ | 14,739 | `2.816420996767335e-14` | `3.0677673160599114e-15` | `5.440092820663267e-15` |
| 旧 Post Gamma 限制组合 17³ | 14,739 | `1.7497114868092467e-13` | `3.514440874462908e-15` | `3.94624697083319e-15` |

## 文件与任务后端证据

程序化 FileWrapper 实际写入临时磁盘 `.lutcalc` 后重开，并由 EditorSession 重开取得请求；保存的显示曲线／色域与算法身份一致。CUBE 导出全部 33³ 节点与独立二进制参照比较；SPI1D 实际导出 1024 点、全部三通道与独立 Decimal 比较，维持 `2e-12`。非中性节点区分 1D 跳矩阵与 3D 转矩阵，不以相同灰轴结果代替验证。

gamma 后端编辑、撤销／重做保留 Display 设置，既有请求不受新编辑污染。带 Post Gamma 主／次级显示转换的 1／4 worker 生成相等；1 worker 的极值输入实际触发 stage16/node0 数值失败，sink 为 aborted。没有 Finder/Files 或第三方软件往返声明。

## 工具链、构建和门槛

- Xcode 27.0（27A266a），Apple Swift 6.4，macOS 27.0（26A428）arm64，Node 22.21.0，Python 3.14.6；实际输出分别归档。
- 全包 Release **443 项执行、0 失败、2 项既有可选夹具跳过**，实际退出 `0`；不是全部旧功能完成率。
- macOS、generic iOS、generic iOS Simulator 三个 Release 未签名构建实际退出 `0`。
- 源码边界与三个实际 App 包资源／直接链接审计退出 `0`。这些检查不能独自证明二进制无等价采样表或来源全量闭合。
- 数值子集实际退出 `0`，包含新显示曲线／两条组合链／独立全网格／1024 点参照的重生成一致性核对，并执行既有 Node、Python、Swift 命令行与批量数值入口；终态见 `numeric-subset.log`。
- 全量发布证据检查实际退出 **2**：真实 `full-scope-acceptance.json` 不存在；没有创建或伪造清单，没有声称完整发布入口通过。

23 条实际命令、28 条日志哈希、124 条源码／参照哈希及 9 条 App 文件哈希与阶段结果归档在 `artifacts/2026-10-02-display-conversion/`。

归档首次哈希核对发现文档同步发生在哈希生成之后，覆盖／精度／roadmap／范围清单的哈希已过期；原清单和首次失败摘要保留。只刷新文档完成后的清单，再实际核对全部文件，不改产品源码或数值结果。

## 未覆盖范围

四个 HDR 显示变体、完整 HDR/OOTF 参数及锚点准备、False Colour／旧 Null／完整限幅政策；其余旧曲线、空间、CAT 与全参数组合；完整 ICC、相机模型与曝光批量、LUTAnalyst 和格式；真实 File Provider 故障、跨设备数值／性能、签名发布和安装升级仍未完成。白平衡／PSST 来源、厂商风格、旧域外 tricubic、任意 3D 逆和 NCP 写出的研究边界不变。UI 全部暂缓，不缩减最终范围。
