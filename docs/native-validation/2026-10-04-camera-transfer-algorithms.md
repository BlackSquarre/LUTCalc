# 2026-10-04 Nikon N-Log／Generic Cineon 算法验收

## 范围与结论

本包闭合既有 Nikon N-Log 与 Generic Cineon 的公开公式、旧兼容公式及默认接线，四个版本身份进入 Double 计划、目录、输出单位与项目往返。没有新增相机或厂商风格，没有把本包等同于 H11、FULL-01/FULL-02 或全量迁移完成。UI 和追加真机性能按用户决定暂缓。

## 公式与来源裁决

- `nikon.nlog.v1` 使用 Nikon N-Log Specification v1.0.0 第 2 节：反射率灰点 0.18、cubic 系数 650、解码分界 452/1023，不额外乘 0.9。原厂 PDF 在 `research/colour/2026-09-23/whitepapers/nikon-nlog-v1.pdf`，SHA-256 为 `037f4dbd8bce2e63b17e3400588131e4b3a17c12fe058320b30de17a907715b4`。
- `nikon.nlog.lutcalc-legacy.v1` 保留旧 `650.1864339`、`451.7887494/1023` 与灰 0.2 线性域，TransformPlan 边界通过 LinearScale 只适配一次。首次 N-Log 证据混用了旧系数和官方名称，已在[补正记录](2026-10-04-nikon-nlog.md)明确撤销其官方验收解释。
- Nikon 官方分段包含规范舍入差异：`encode(0.328)=0.4416312310951134`，反解约为 `0.32828876825888234`。保留原公式；最小复现见 artifacts 中 `nikon-formula-difference.json`。灰点编码约为 `0.3636677701171387`，相同 scene 0.18 经旧兼容边界编码约为 `0.36377207781050365`。
- `cineon.v1` 使用 black=95、white=685、gamma=0.6、code=1023 的公开 black-offset 公式；`cineon.lutcalc-legacy.v1` 保留旧线性负值 toe 和灰 0.2 域。固定来源为 Colour Science commit `ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5`、Sony Imageworks OpenColorIO-Configs commit `c0ff0e96574e823606a81e62e3867d9d8ba238db` 第 161–164 行。来源文件、URL、SHA 与不可进入运行资源的标记见 `research/colour/2026-10-04/algorithm-sources/manifest.json`。
- Cineon 官方编码无定义的负值显式拒绝；低 full-code 输入解码与曝光后可能仍为负值，因此公开验证预设 `cineon.exposure-one.v1` 输出 linearScene，不假造 log 延拓。旧预设保持旧 toe 编码。
- Nikon Z6/Z7 和 Generic 按公开／旧兼容策略选择对应身份；没有因共享 Cineon 公式擅自启用 RED 相机默认。N-Log/Cineon 完成时目录为 56 曲线、18 色域、52 预设；随后 Sony S-Log 包将当前目录扩展为 60 曲线、19 色域、56 预设；66 个既有相机身份中公开默认可用 37、旧兼容可用 28。

## 契约先行与独立参照

先行契约覆盖分段相邻值、负值／HDR、非有限、0.18／0.2 单位、data／video 边界、默认路由、项目磁盘往返与失败原子性。实际研发参照为独立 90 位 Decimal 脚本 `tools/native-validation/camera-transfer-reference.py`，四身份完整 10/12 位码值及分界邻域；旧兼容另实际运行原 `js/gamma.js`，由 `generate-camera-transfer-legacy-reference.js` 生成研发夹具。这些夹具没有加入 App。

| 身份 | Decimal 标量最大尺度化误差 | 实际旧 JS 最大尺度化误差 |
| --- | --- | --- |
| Nikon 公开 | 6.498232168572208e-16 | 不适用 |
| Nikon 旧兼容 | 7.178178319283952e-16 | 3.3679011133683414e-16 |
| Cineon 公开 | 8.383714094919727e-16 | 不适用 |
| Cineon 旧兼容 | 6.760411136787471e-13 | 3.775379359482439e-13 |

冻结门槛仍为 `2e-12`，误差按 `abs(actual-reference)/max(1,abs(reference))` 计算，没有调整公式、网格、位宽或插值来通过验证。

## 实际执行与结果

证据目录：[camera-transfer-contracts](artifacts/2026-10-04-camera-transfer-contracts/commands-final.json)。最终命令、开始时间、退出码和日志在 `commands-final.json`，共 40 条命令均符合记录的预期退出码。

- Debug／Release 定向契约通过；Swift Release 全量 693 项、0 失败，LUTFormats 两项既有外部夹具按设计跳过。八包计数见 `swift-test-summary.json`。
- 使用 Release `LUTReferenceCLI --size <17|33|65> --output <path> --preset <id>`，四身份各完整 17³／33³／65³，共 12 个 CUBE、1,261,900 节点、3,785,700 通道。独立 Decimal 逐通道验证全部通过，最大尺度化误差 `9.217626661950362e-14`。各文件 max／RMS／P99 见 `cube-decimal-summary.json`。
- 故意改动一个节点后的独立 verifier 退出 1，正确拒绝；未改动真实生成文件。
- macOS、generic iOS、generic iOS Simulator 三个平台未签名 Release 构建退出 0；155 个 Swift 生产源码审计与三个实际 App 包审计通过。
- `check-release-evidence.py` 退出 2，真实 `full-scope-acceptance.json` 缺失；未创建或伪造全量清单。
- 工具链：Swift 6.4、Xcode 27.0（27A266a）、macOS 27.0.1（26A434）。完整 SDK／Python／Node 版本在 toolchain 日志。

实际生成 CUBE 位于 `/tmp/lutcalc-camera-transfers-final-20261004/`，大小与 SHA 在 `generated-file-manifest.json`；测试 JSON 位于 artifacts 的 debug／release 子目录。19 个代码、契约和脚本文件的冻结副本在 `source-snapshot/`，夹具 SHA 在 `fixture-hashes.json`；全部证据哈希见 `SHA256SUMS.txt`。执行驱动 `run-evidence.py` 保留实际调用流程。首次诊断、错误参照点、编译和 shell 包装失败保留在 `initial-diagnostics.txt` 等历史日志，没有删除失败记录。

## 未覆盖与继续方向

本包未完成 S-Log2／S-Log、C-Log、REDLogFilm 与相关色域、Pocket Film、DJI 旧曲线、SUP2 raw 校准／连续 EI／sensor 单位／camClip／高 EI shoulder、9 个旧资源及 45 个查表注册项的完整替代、HDR/OOTF、完整 ICC 和 LUTAnalyst。文件／设备／目标软件／性能／签名验收也未因此完成。继续既有算法范围，公开定义不足的项目保留研究阻塞与最小复现；Goal 保持 active。
