# 2026-10-02 相机身份与曝光状态非 UI 阶段验收

## 范围与来源

接续已冻结的 [AWG3 阶段](2026-10-02-awg3.md)，本包实现 66 个相机项的稳定身份、ISO／曝光状态、明确的输入默认策略和项目／文稿／任务后端。UI 按用户要求暂缓。

`CameraCatalog.swift` 保存旧注册的 make、model、baseISO、三类 ISO 政策、默认曲线／色域名称及黑白裁剪辅助量。来源为 `js/lutcamerabox.js`，SHA-256 `77d734241d39dc9a1c5d892cfbba8a5432eda5ec1a8ff05a7f69d94f381d5a2a`；冻结旧 handler 参照为 `exposure-batch-legacy-reference.json`。这属于相机元数据，不是色彩采样表；运行时不读取旧 JS、参照文件或厂商 LUT。`reportedNativeISO` 表示旧注册报告值，不声称全部型号均独立实测；Generic 为 nil，其计算 baseISO 仍为 800。

## 契约与实现

- `CameraExposureSettings` 身份为 `lutcalc.camera-exposure-state.v1`，保存 profileID、recordedISO、stopCorrection、source、inputPolicy。17 项 CineEI、1 项曲线参数、48 项 bakedGain 政策分别保留。未知身份、非有限值、无效 ISO、状态错配和不可表示的增益均拒绝。
- CineEI 以 Double 的 `log(ISO/baseISO)/log(2)` 求 stop，再按精确 binary64 的旧 `toFixed(4)` 语义舍入。UInt64 全宽乘法避免先乘 10000 引入第二次舍入。Venice base500／ISO1501 对应 stop1.5859、gain3.0019501084917075，不能用 ISO 比例 3.002 代替。四位 stop 是相机旧政策，最终生成仍为 Double，不降低 LUT 位宽或序列化精度。
- CineEI 手动 stop 更新 ISO 为正整数 `round(baseISO*2^stop)`；曲线参数和 bakedGain 的 ISO 编辑保留手动 stop。批次 override 替换 stop、保留 recordedISO／曲线参数。黑白辅助量为 `0.18*2^(metadataStop+stopCorrection)`，不自动裁剪生成结果。
- 三种 inputPolicy 分别为显式保留当前输入、已有旧兼容默认、已有公开算法默认。选择相机时才应用默认；ISO／stop 编辑保留用户随后选择的显式输入，不重新选默认。ISO 编辑会更新当前两槽参数化 Log C 的 EI，不支持的公开 EI 明确拒绝；后续显式槽编辑仍可独立保存。
- 新项目 schema19 严格保存相机六字段和算法／profile／source／policy 身份，计划身份和批次指纹参与相机状态。所有 settings copy helper 保留状态，batch override 有单独来源身份。schema1–18 偷带相机字段或相机算法版本拒绝；合法历史项目迁移为 nil，读取不自动改写。
- 文稿后端增加相机选择／完整状态／ISO／stop 编辑 API，校验 revision；失败原子、用户 LUT 资源与批次预设保留，undo／redo、参数化 gamma 复制、不可变任务请求及本地磁盘重开验证通过。仅编辑后端，没有修改控件、布局或交互。

## 默认覆盖的边界

当前目录为 46 曲线、15 色域、42 个转换预设，另有 66 个相机身份。两个默认策略逐项实际执行，机器记录见 [可用性表](artifacts/2026-10-02-camera-state/outputs-camera/default-availability.json)。

| 输入默认策略 | 可选择 | 尚不可选择 |
| --- | --- | --- |
| 旧兼容已有默认 | 22／66 | 44／66 |
| 公开算法已有默认 | 31／66 | 35／66 |

公开策略目前支持标准 Sony S-Log3／S-Gamut3或cine、F-Log2、LogC4／AWG4、显式 SUP3 scene／AWG3、original Apple Log／Rec.2020、V-Log／V-Gamut。旧兼容策略只覆盖已有的 S-Log3／F-Log2 对应身份。Venice 特殊色域不能替成标准 cine；公开 compact Log C 不能冒充完整旧 shoulder。缺失默认抛 `unsupportedDefaults`，不自动替换为通用曲线。

表中的 `blocked` 仅指当前 resolver 不支持，不表示全部项目已研究阻塞。Generic 连续 Cineon／Rec.709、Venice、Canon／Blackmagic／DJI／Nikon／RED 等仍需各自来源、实现和验收。

## 先行失败与实际终态

核心／项目先行契约 `contract-red.log` 退出1，生产 API 缺失，首轮测试小数写法遗漏同时修正。`debug-first.log` 退出1，因为初生成身份使用 `sony-model`，与契约 `sony.model` 不一致；首轮独立 JSON 保存在 `initial-camera-state-independent.json`，修正命名空间后重生成。文稿后端先行契约 `document-red.log` 退出1，随后落实 API。全部原失败与中间日志保留。

最终定向 Debug 为9项，加单独任务契约1项，均退出0；完整 Release 从8个 `.xctest` 汇总为 **512项／0失败／2项既有夹具跳过**。跳过为未提供旧 `.labin` 研发夹具及公开 NCP specimen，不能视为两项互操作通过。

| 独立范围 | 数量 | 最大尺度化误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 498 个 ISO／状态案例 ×4 值，80／120位 Decimal | 1,992 | `1.436449758384103e-15` | `1.1681073686616763e-16` | `5.4570150362630365e-16` |
| 每套8 CUBE＋4 SPI1D，独立 Python 全点读回 | 3,739,032通道 | `2.220305848821056e-16` | `5.884945856470183e-17` | `2.132375847833426e-16` |

42 个 Fraction 精确 binary 舍入边界逐位通过，132 个冻结旧 handler 的 stop／gain 对照通过。三套实际输出分别来自早期 Debug、最终 Debug 和 Release，独立全点读回全部通过。四个配置为 Venice ISO1501、FX9 ISO2401、FX6 Flexible ISO2401／manual0.125、Generic ISO2401／manual-0.375；各完整33³／65³ CUBE，域 `[-0.1,1.2]`，33³配置另有完整1024点 SPI1D。输入输出显式 linear scene／同色域，证明曝光后端，不证明全部相机默认色彩转换。

schema18 来源为上一冻结 AWG3 包真实 EI800／CAT02／33³ 项目，原 manifest SHA-256 `c4241fd2a05d3f5de93f68189300186503deb67e487c91f4bb69c1582e495453`；本包 Debug／Release 各保存读前／读后字节，独立核对来源与两份字节均一致。旧包没有回写。

worker1／4 完整33³相等，取消 sink abort，曝光溢出定位 stage4／sample0，未提交部分结果。既有六个真实本地 SIGKILL／独立重启回归也在 Release 通过，保存于 `process-release/`；这是本地回归，不是新增 iPhone 后台或提供商恢复证据。

## 工具链、命令与证据

Xcode27.0／27A266a，Swift6.4，macOS27.0／26A428，arm64，Node22.21.0，Python3.14.6。全部实际命令、开始／结束 UTC 和退出码见 [commands.json](artifacts/2026-10-02-camera-state/commands.json)；[results.json](artifacts/2026-10-02-camera-state/results.json) 汇总终态、误差、默认可用性与源码归档 SHA。

实际门槛：

```sh
python3 docs/native-validation/artifacts/2026-10-02-camera-state/run-gates.py
python3 docs/native-validation/artifacts/2026-10-02-camera-state/run-commands.py independent-files-final.log python3 tools/native-validation/verify-camera-state-files.py
python3 docs/native-validation/artifacts/2026-10-02-camera-state/run-commands.py prepare-results.log python3 docs/native-validation/artifacts/2026-10-02-camera-state/prepare-results.py
python3 docs/native-validation/artifacts/2026-10-02-camera-state/freeze-evidence.py
```

Release测试、macOS／iOS／Simulator 新 DerivedData 路径的未签名 Release 构建、数值子集、源码边界和实际三个 App 包审计均退出0。源码审计覆盖133个 Swift文件；扩展名和直接链接检查不独自证明全部等价采样表／间接依赖合规。源码、脚本、夹具、中文契约、实际命令、日志、输出、恢复进程文件、App 与 helper 均记录哈希，源码 tar 逐文件读回核对。最终冻结状态见 `artifact-check.txt`。

全量证据检查实际退出 **2**：真实 `docs/native-validation/full-scope-acceptance.json` 缺失，未创建替代清单。

## 未覆盖与下一步

仍欠完整相机默认、Generic、连续EI／真实shoulder、SUP2校准及sensor生成、完整camClip辅助分析链；相机元数据不是物理实测。本包没有新增设备数值／后台、iCloud／File Provider、性能预算、签名／归档／公证或渠道证据。

其余非 UI 缺口见[当前剩余清单](2026-10-02-non-ui-remaining-current.md)。原 H01–H14／FULL-01 至 FULL-08 范围保持，FULL-02／FULL-08／H12／H14 不勾选，Goal **active**。
