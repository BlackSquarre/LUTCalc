# 2026-10-02 相机 ISO/EI 与曝光组规则复核

## 范围和实际执行

UI 暂缓。本记录执行研发端的旧纯函数／handler，冻结当前相机注册和曝光组计算行为，不创建界面、不把旧 JavaScript 接入产品，也不声称 FULL-02 已迁移。

`generate-exposure-batch-legacy-reference.js` 实际调用 `LUTCameraBox.cameraList`、`changeCineEI`、`LUTGenerateBox.generateSet`／`got1D`；用输入对象代替 DOM 控件，仅收集数值、名称和恢复后的字段。实际命令退出 0，旧源码哈希、完整结果和重生成检查保存在 `tests/fixtures/native-contracts/exposure-batch-legacy-reference.json`；日志见 `artifacts/2026-10-02-exposure-batch/legacy-generation.log`。

## 相机规则不能合并

实际有效相机 **66 项**：type 0 为 17 项，type 1 为 1 项，type 2 为 48 项；注释中的 Nikon Z780 不计入。注册项是旧预设元数据，并非所有参数都已获独立厂商实测确认。

- type 0：CineEI。`changeCineEI` 使用 `log(recordedISO/nativeISO)/log(2)`，再 `toFixed(4)` 写 stopShift。后续 `LUTGamma.setParams` 的 stopShift 会覆盖先设置的直接 ISO 比例，实际 gain 为 `2^roundedStop`。
- type 1：ARRI Alexa / Amira 的记录 ISO 曲线参数；handler 不据 ISO 比例改 stopShift。`setParams` 会调用曲线 changeISO，LogC Sup 3/4 等有 EI 参数和高 ISO knee，不能以一个曝光乘数替代。
- type 2：已烘焙增益；ISO 不据比例自动改 stopShift，手动曝光修正仍独立存在。`setParams` 会通知所有曲线 changeISO，因此实际参数依赖还须按所选输入／输出算法分别核对，不能仅按相机类型判断所有曲线不依赖 ISO。
- Generic 注册 iso=800、Cineon／Rec709、黑白 stop=-9／9；选择时 nativeLabel 显示 N/A。不能把其 800 当成经证实的物理原生 ISO，也不能在缺 Cineon 实现时替换为别的曲线并称默认联动完成。
- `lutmessage.js` 的 camClip 是 `0.18*2^(wclip+stopShift)`。当前旧 `gamma.js` 使用它输出辅助分析表；它不是所有输出都必须立即套用的最终 clamp，不能与格式／用户限幅混淆。

### CineEI 舍入差异的实际例子

Sony Venice 的 nativeISO=500，recordedISO=1501。旧 handler 保存 stopShift=`1.5859`，实际 worker gain=`3.0019501084917075`；直接比例为 `3.002`。此差异明显大于普通数值舍入预算，后续完整原生相机模型须区分旧政策与新的精确比例身份，并用独立参照验证；本轮没有替旧相机悄悄选择一个新结果。

## 曝光组实际行为

旧 UI 选择范围：minimum=-4/-3/-2/-1，maximum=1/2/3/4，subdivisions=1/2/3/4，共 **64 组、864 个曝光点**。worker 使用 setVal 的完整 Double 增益，不使用显示时四舍五入至两位的 stopShift；批次曝光替换当前修正，不加到原 stopShift。成功／失败结束后恢复原名称和修正。

旧后续值通过 `setVal+=1/subdivisions` 累加，三分之一组会产生微小漂移。此次原生批量身份 `native.exposure-batch-rational.v1` 按整数 numerator/subdivisions 逐点求值，精确包含端点和正零；已保存旧全部结果，最大旧／新 stop 差为 `8.881784197001252e-16`，不称旧逐位相同。独立 80 位 Decimal 参照另行生成，文件名在全部 64 组保持一致。

旧 `generateSet` 首次名称判断引用未定义的 `setVal`。minimum=0 的实际最小复现得到 `ReferenceError: setVal is not defined`；该 minimum **不在旧 UI 的正常选择范围**，正常 64 组因负 minimum 的短路条件均可执行。原生后端允许零起点并通过契约，但本轮未修改旧 JS。

## 下一步和未完成范围

相机稳定 ID、默认曲线／色域／范围的完整映射、来源、切换规则、ISO 参数依赖、ARRI LogC3 与高 ISO knee、Generic 连续算法、完整裁剪／辅助链和项目版本化仍未实现。先冻结这些契约，不能拿本轮注册盘点或曝光批量通过抵消 FULL-02 的缺口。

本轮曝光批量后端的实际实现与平台结果见[阶段验收](2026-10-02-exposure-batch.md)。FULL-02／FULL-08 和 Goal 保持未完成，UI 继续暂缓。
