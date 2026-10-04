# 原生数值内核：实现契约与优化边界

## 2026-10-02 相机曝光状态契约补充

`lutcalc.camera-exposure-state.v1`保存稳定profileID、正整数recordedISO（1...9007199254740991）、Double stopCorrection、来源和输入policy。CineEI按Double `log(ISO/baseISO)/log(2)`后对精确binary64执行旧四位小数舍入，ties远离0、保留符号零，不能先Double乘10000双重舍入，不能用ISO比例代替最终增益。手动CineEI更新ISO为正整数round(baseISO*2^stop)，不可表示值拒绝。其他两类ISO编辑保留手动stop。

批次override替换stop且不改ISO／EI。相机辅助黑白scene量为0.18*2^(metadataStop+stopCorrection)，不自动clamp。相机ISO编辑显式更新当前LogC两槽EI，公开不支持EI拒绝；后续显式槽编辑独立保存。默认输入政策仅相机选择时执行，ISO／stop编辑不重新选择默认。明确当前输入策略保留已有输入，缺失默认不得fallback。详见[相机验收](native-validation/2026-10-02-camera-state.md)，完整默认／sensor／shoulder／camClip链仍欠。

## 2026-10-02 Log C 公开紧凑式边界补充

`ARRILogCCompact` 按公开参数分段计算，区分 SUP 2／3、sensor signal／scene exposure 和 11 个文档 EI。算法系数是公开解析式的参数，计算路径始终为 Double；不查采样值，不插值未知 EI，不在内核自动应用相机或格式限幅。IEEE Double 的 cut、e*cut+f 分支边界明确保留，选定分支结果由独立 80／120 位 Decimal 验证，门槛仍为 `2e-12`。

公开六位参数本身有接缝，不能据公开 decode 式声称连续唯一反求；EI 1600 的紧凑式与实际相机 shoulder 存在文档明确的高光近似，EI 更高的完整公式仍研究阻塞。旧标量／数组和域外延拓冲突已存实际最小复现。详见[公开内核验收](native-validation/2026-10-02-logc-compact.md)及[研究边界](native-validation/2026-10-02-logc3-shoulder-research.md)。此前内核包尚未接入 TransformPlan、项目或 App 生成；后续 scene 路由现已独立接线，见[接线验收](native-validation/2026-10-02-logc-scene-routing.md)，不能沿用内核结论代替其他域或完整相机验收。

日期：2026-09-23。状态：已明确的实现要求，尚无 Swift 实现或性能收益证明。先读[交接入口](native-swift-handoff.md)，精度判定仍以[精度规范](native-swift-precision.md)为准。

## 1. 先固定语义，再优化

现有复杂度主要来自同一数值在不同位置代表不同东西。第一步不是复制整份 `gamma.js`，而是用值类型和纯函数消除隐含状态。

### 1.1 必须统一的类型约定

| 类型 | 契约 |
| --- | --- |
| `RGB64` | 三个 Double；默认不裁剪，所有公开计算入口检查有限性 |
| `Matrix3x3` | 逻辑下标 `[row,column]`；文件/测试为 row-major；运算 `y=M*x`，x 为列向量 |
| `CodeRange` | `bitDepth, blackCode, whiteCode, maxCode`，满足有限整数、`0 ≤ black < white ≤ max` |
| `LinearReference` | `legacyGrey02`、`sceneReflectance`、`absoluteNits`；绝对/相对转换必须带明确 luminance scale |
| `TransferDefinition` | 稳定 ID、版本、编码/解码、输入输出标度、分段点、合法域、负值与域外策略、来源 |
| `TransformPlan` | 不可变的算子列表；保存输入/输出域、阶段 ID、有效参数及版本；UI 不可修改运行中的计划 |
| `StageTrace` | 每阶段输入/输出 RGB、单位、色域 ID、范围、是否裁剪；只在诊断小样本启用 |
| `NumericFailure` | `stageID`、样本索引、原输入、错误类别；不能用零或大常数替代错误 |

不要同时维护“先乘 0.9 的包装曲线”和“调用方也乘 0.9”的两条链。原生曲线接口统一由 `TransferDefinition` 声明规范的线性标度；只有进入/离开旧兼容调节域的适配器做标度换算。D-Log2 的 `scene = legacy * 0.9`；其他厂商逐项确认，不能根据中灰命名推断全部转换。

### 1.2 范围函数（禁止用含混的 legal/data 布尔值穿透全管线）

设 `C` 是整数码值，`D=C/maxCode`，`V=(C-blackCode)/(whiteCode-blackCode)`：

```text
videoToData(V) = (V*(whiteCode-blackCode)+blackCode)/maxCode
dataToVideo(D) = (D*maxCode-blackCode)/(whiteCode-blackCode)
```

8/10/12-bit 视频 RGB 黑白码分别为 16/235、64/940、256/3760。这里只描述所选 RGB 信号范围，不推广到 YCbCr 色度码。函数不裁剪超黑/超白值。曲线的规范信号域不一定都是 video-normalized，按定义转换一次。

旧方法 `linToLegal` 输出的是 video-normalized；`finalOut` 在 data 输出时才转成 full-code-normalized。**名字中的 Legal 不是整数码值。** `LUTDomain` 则是采样横轴，与 `CodeRange` 分开；例如 DOMAIN_MIN=-1 不表示 blackCode=-1。

## 2. 真实处理顺序与计划编译

### 2.1 当前 3D 生成路径（`g=true`）

以下顺序直接来自 `inCalcRGB` → `colourspace.calc` → `outCalcRGB`；是迁移追踪表，不等于允许省略每个算子内部的域变换。

| 阶段 | 旧方法 | 契约/注意事项 |
| --- | --- | --- |
| 01 | `inCalcRGB` 网格与 `sIn` | 生成编码域输入；R 最快、G 次之、B 最慢 |
| 02 | 输入 `linFromD/L` | 解码到旧线性标度；原生通过显式适配器达到相同语义 |
| 03 | `csIn[curIn].lc` | 输入转换到旧工作空间；矩阵、Lab、IDT、特殊输入分别标识 |
| 04 | 曝光 `eiMult` | 对三个通道乘相同增益；旧 NaN→0 行为列为缺陷，不复制 |
| 05 | `FCOut` | **在白平衡之前**计算 False Colour 辅助数据；不能挪到最终图像上重算 |
| 06 | `wb.lc` | 白平衡/色温转换 |
| 07 | `PSSTCDLOut` | 工作空间中的色相/亮度相关变换 |
| 08 | `ASCCDLOut` | SOP 再饱和度；负值语义必须显式保留或有版本修正 |
| 09 | `multiOut` | Multitone |
| 10 | `HGOut` 或 `csOut.lc` | Highlight Gamut **替代**普通输出色域路径，不能两者重复执行 |
| 11 | `SDRSatOut` | SDR Saturation |
| 12 | `colourspace.gamutLimOut` | 计算限制和相关辅助数据，传给后续阶段 |
| 13 | `kneeOut` 或输出 `linToL` | Knee **替代**该输出编码调用，不是编码后再随意附加 Knee |
| 14–16 | `blkHiOut`、`blkGamOut`、`displayOut` | 按旧顺序处理输出编码数值；每个方法内部域转换要继续追踪 |
| 17 | `gamma.gamutLimOut` | 消费第 12 阶段辅助数据 |
| 18 | `fcOut` | 用第 05 阶段的辅助数据形成 False Colour 输出 |
| 19 | `finalOut` | 范围映射和最终限幅，拆成独立策略 |

工作空间必须沿用旧 `system` 的定义及白点，不能在保留原 PSST/CDL 系数时直接换成 ACEScg。未来改为其他工作空间属于独立算法版本。

`g=false` 的预览/分析调用会跳过输入 `lc`，并使用输出 `lf`；因此它**不是可以直接复制到导出的同一入口**。原生以 `InputStage` 指定缓冲区已经处理到哪一步，禁止用两个难以解释的布尔值决定所有行为。

1D `oneDCalc` 不经过整条 colourspace 管线：解码→曝光→1D CDL→Knee/输出编码→黑白电平→Black Gamma→显示转换→finalOut。新实现用同一批算子组成明确的 1D 计划；不把 3D 灰轴采样自动当成全部 1D 功能等价。

### 2.1.1 ASC-CDL 旧工作空间版本（2026-10-02）

`lutcalc.asccdl-working-linear.v1` 明确采用保留旧引擎的 Sony S-Gamut3.cine／D65 工作空间和线性标度，不声称标准 Rec.709 ASC-CDL 认证。3D 在曝光之后、输出色域之前执行阶段 08；即使输入输出色域相同，启用该算子也必须经过工作空间转换。

- scene 值先除以 `0.9`，逐通道计算 `v = input*slope+offset`。`v<0` 保留负值；其余计算 `pow(v,power)`。
- 3D 的饱和度使用工作空间 RGB→XYZ 矩阵的 Y 行，计算 `Y+saturation*(channel-Y)`，最后乘 `0.9` 回到 scene 单位。不得换用固定 Rec.709 系数。
- 1D 只执行独立通道 SOP，不应用色域矩阵或饱和度；目前仅接受输入输出色域相同的计划。不能将该 1D 文件宣称为启用饱和度后的 3D 等价表示。
- 保留有限的负 slope／saturation 及零／负 power 参数；奇点、溢出与非有限结果显式失败，诊断包含阶段和节点，不复制旧 NaN→0。
- 配置缺失或 disabled 保持此前无调节行为；配置和算法身份进入原生 schema 4、不可变请求及撤销快照。

先行契约、冻结旧源码参照、独立有理数／70 位 Decimal 参照及实际误差见[ASC-CDL 阶段验收](native-validation/2026-10-02-asc-cdl.md)。其他调节阶段和完整旧链仍须独立验收。

### 2.1.2 SDR Saturation 旧输出线性版本（2026-10-02）

`lutcalc.sdr-saturation-output-linear.v1` 在输出色域转换之后、输出编码之前执行阶段 11。它不是 HLG OOTF、显示变换或通用 saturation 乘数。支持保留旧用户参数的 `gamma∈[1,2]`，由输出原色 RGB→XYZ 的 Y 行解析求系数。

scene 输入先除以 `0.9` 到旧线性标度，再逐通道计算 `q=input/12`，非负值取 `q^(1/gamma)`，负值保留线性除法。计算 `Y=Σ(y_i*q_i)`；`Y≤0` 保持原始输入，不返回 q。`Y>0` 时保留旧 Pb／Pr 差量，将 Y 提至 gamma 次幂后重建 RGB，乘 12，再乘 `0.9` 回到 scene 单位。独立参照可消去 Pb／Pr，写为 `12*(q_i+Y^gamma−Y)`。

不裁剪负值、超白或 HDR；非有限值／溢出明确失败并定位阶段 11。启用该三通道耦合阶段的 1D 生成请求在写文件前拒绝，禁止取灰轴冒充等价表示；disabled 配置保留无调节数值行为。项目字段从 schema 5 起保存。

旧内核、独立 Decimal、33³／65³ 网格与实际旧解码／色域／曝光／CDL／SDR 链的证据见[阶段验收](native-validation/2026-10-02-sdr-saturation.md)。完整 HDR/OOTF 和其他输出阶段仍未完成。

### 2.1.3 Multitone 旧工作空间版本（2026-10-02）

`lutcalc.multitone-working.v1` 在阶段 9 执行，位于 ASC-CDL 之后、普通输出色域或 Highlight Gamut 之前。工作空间为 Sony S-Gamut3.cine，scene→旧线性单位适配仍为除以 `0.9`，参考灰为旧 `0.2`／scene `0.18`。

- 用户的 17 个 saturation 参数位于 −8 至 +8 stop，值域 `[0,2]`，按 `log2(Y/0.2)+8` 线性插值，域外使用两端参数；`Y≤0` 使用首参数和中性 Y，不能对负亮度取对数。
- 色调参数保存原有 8-bit hue／saturation 身份及有限、严格递增的 stop。颜色按明确 HSL（L=0.5）公式逐色调计算，然后 Rec.709→工作空间→输出色域。不得生成或打包旧 256×256 色方格。
- 旧版本在工作空间缓冲区混入“预先转换到输出色域”的色调值；该行为明确保留，不能悄悄按更常见的工作空间色调模型修正。`sat≥1` 直接使用中性 Y；`sat<1` 在色调 stop 间插值、端点保持，并用工作 Y 系数归一化色调亮度。色调 `Y2≤0` 回退到中性 Y。
- 输出为 `mono+sat*(input−mono)`，不 clamp 负值／HDR；非法参数、溢出或非有限结果明确失败。启用 Multitone 的 1D 请求在写文件前拒绝；disabled 保留无调节路径。
- 项目字段从 schema 6 起保存。参数是用户控制点，不是厂商采样资源；算法版本和快照必须随项目保留。

独立全网格使用确切 IEEE754 输入、精确有理数原色与 70 位 Decimal 计算，避免在亮度抵消附近将另一个低精度 Double 参照误差算到产品头上；保持 `2e-12` 门槛。实际结果和原始失败诊断见[阶段验收](native-validation/2026-10-02-multitone.md)。完整调节链仍未完成。

### 2.2 编译与可允许优化

`resolveSettings` 先产生唯一 `EffectiveSettings`：当前编辑值为基础；选择相机/格式的 UI 动作形成明确变更；格式的硬性约束冲突返回错误或在导出前显示具体修正，计算器不暗改。报告始终保存实际有效设置。

`compilePlan` 校验域、方向、已验证状态与纯算法来源，然后编译不可变算子。每个算子声明 `inputDomain`、`outputDomain`、`readsAuxiliary`、`writesAuxiliary`、`isAffine`、`changesRange` 和 `mayClip`。

**先优化计划编译和内存分配；默认关闭矩阵融合。** 验证后只融合相邻、同域且无观察点/辅助数据/裁剪的仿射算子：

```text
A(x)=M1*x+b1; B(x)=M2*x+b2
B(A(x))=(M2*M1)*x+(M2*b1+b2)
```

禁止跨过曲线、Knee、饱和度、采样、色域限制、False Colour 快照融合。即使数学上相同，浮点舍入仍可能改变；融合计划必须通过未融合 Double 计划和独立参照。不能将调节开启时的 `Mout*Min` 当成永远可预合并的色域转换。

## 3. 矩阵与白点适应

### 3.1 原色推导

对每个原色 `(x,y)`，构造列向量 `(x/y,1,(1-x-y)/y)`，形成 P。白点 `W=(xw/yw,1,(1-xw-yw)/yw)`；求解 `P*S=W`，得到 `M=P*diag(S)`。

使用带部分选主元的 3×3 LU 求解，复用同一分解求三个单位列得到逆矩阵；禁止只把旧余子式公式再抄一遍。主元为零/非有限即失败；主元相对行尺度太小时进入条件检查，不用固定的“行列式小于 0.001”判断。

以 `kappaInf=normInf(M)*normInf(invM)` 辅助诊断，并测 `normInf(M*invM-I)`。初始自定义色域策略：`kappaInf>1e8` 标为病态并拒绝生成；此阈值只是产品防护界，**不证明**小于阈值就满足精度。其余仍需通过残差和已冻结样本误差门槛；标准色域不得因该阈值静默被更换。

虚拟原色可以有负坐标或位于光谱轨迹之外，不要强制 `x+y≤1`。要求有限值、非零 y、非退化基底、可接受条件数；负值本身不是错误。

### 3.2 CAT 与缓存

使用已选 CAT 的固定矩阵 A：`CAT=inv(A)*diag((A*Wd)/(A*Ws))*A`；从源空间到目标空间为 `inv(Mdst)*CAT*Msrc`。源锥响应分母为零/非有限时失败。D65→D60 只做一次。相同白点且同一规范标度时可返回单位 CAT。

缓存键包含原色、白点、CAT ID/版本、矩阵来源与引擎版本的**精确值**；不能用 UI 四舍五入后的字符串做键。矩阵按设置计算一次，像素循环只做乘加。矩阵数据转为 `simd_double3x3` 时显式按列装配。

## 4. 网格与插值

### 4.1 唯一布局

```text
nodeIndex(r,g,b)=r+N*(g+N*b)
channelOffset=3*nodeIndex+c
x[c]=domainMin[c]+index[c]/(N-1)*(domainMax[c]-domainMin[c])
```

`N≥2`，域每通道有限且 min<max。内存先检查整数乘法溢出，再分配。通过全局整数节点索引计算坐标；不能靠浮点逐步累加，也不能按块重新归一化。输入/输出缓冲区默认 interleaved RGB Double，各格式另做轴序适配。

### 4.2 四面体插值的单一写法

仅用于用户导入 LUT、分析与生成缓存，不作为内置 Log 的公式替代。对域内点归一化 `u=(x-min)/(max-min)*(N-1)`，`i=min(floor(u),N-2)`，`t=u-i`。上端点必须得到 `i=N-2,t=1`。

将三个小数坐标按降序排列为 `ta≥tb≥tc`，相等时固定轴序 R、G、B。四个顶点：`v0=000`、`v1=ea`、`v2=ea+eb`、`v3=111`；权重：

```text
w0=1-ta; w1=ta-tb; w2=tb-tc; w3=tc
out=w0*F(v0)+w1*F(v1)+w2*F(v2)+w3*F(v3)
```

这覆盖六种轴序及相等边界，不需要六份独立插值代码。域内权重非负、和为 1；三通道使用同一组权重。三线性插值是八角点张量积，和四面体在非仿射样例上通常不同。

### 4.3 域外和 cubic

插值模式与域外策略是两个字段：先实现 `reject` 与 `clampToDomain`。旧 cubic/tricubic 的边缘延拓单独为 `legacyExtensionV1`，在对应样本和系数审计完成前禁止显示“已支持”。不得把 clamp 结果作为旧外插的替代。

自定义新曲线可选择保持单调的 Hermite 模型，但旧 cubic 兼容不自动改成它。过冲不是简单一律裁剪：需要明确模式行为。当前 `LUTVolume` 每次调用复用 `this.rgb/R/G/B` 暂存；Swift 版每个计算任务独占工作区，不在共享对象中写暂存数组。

## 5. 求根、反函数与 LUTAnalyst

### 5.1 单变量反求

优先使用已验证的解析逆函数。没有解析逆时，调用方必须给定定义域、单调性/分支、目标和容差，先确认端点或有效括区间。不能使用巨大数值作失败标志。

先实现容易验证的二分参考解，再增加 Brent 加速。连续区间且端点异号是普通 bracket 求根的前提；不得以 `fa*fb<0` 判断（乘积可能溢出/下溢），直接比较符号。[SciPy 的 Brent 接口规范](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.brentq.html)可作为独立算法验证资料，不进入 App。

返回 `SolveResult`：`status, value?, residual, bracket, iterations, evaluations`。状态至少包括 `converged, notBracketed, nonUnique, nonFinite, maxIterations, cancelled`。初始容差 `xAbs=1e-12`、`xRel=4*Double.ulpOfOne`、`fAbs=1e-12`、`fRel=2e-12`，上限 128 次；这是起始配置，按实际曲线域冻结后使用。

成功需同时满足 x 区间误差和 f 残差（或精确命中零）；只能满足一项时报告未收敛。返回最优有限候选可作诊断，但不能作为成功值。不得越出指定域自动找根。平段导致多解时返回区间/`nonUnique`；非单调曲线只有在已提供分支时求解。

### 5.2 三维与分解边界

LUTAnalyst 的灰轴提取、TF/颜色分离是**一种分析分解**，不是恢复相机原始光谱响应或唯一厂商公式。必须报告采样/插值方法和重建残差。

任意 3D LUT 可能裁剪、多对一或局部奇异。若后续实现 3D 反求：显式限定目标域，采用局部 Jacobian、线性求解、阻尼/回溯和信赖范围；不显式求逆乘残差，不把一次局部收敛当作全局唯一证明。该任务需要独立专项规格，本轮**不授权实现 AI 自行发明求解器**。

旧代码会人为修改首尾点斜率以便反求。这种修正必须保留原数据并输出修正量，不能伪装成原 LUT 本身可逆。首版分析任务先覆盖严格单调 1D、已知可逆仿射 3D、裁剪失败样例；其余完整迁移任务仍保留未完成。

## 6. HDR、裁剪与预览

- PQ 的绝对亮度、HLG 的场景/显示变换、OOTF 与编码函数分别建模。请求保存峰值亮度、参考白、黑位及系统 gamma 等实际所需参数；默认值要有来源，不能“屏幕多少亮度就改变导出 LUT”。
- `clip=false` 的原意需要拆分：旧 `finalOut` 即使关闭用户 clip 仍应用 `bClip/wClip` 和 HDR 上限。这是实测旧行为，不是关闭 clip 就无限域。新计划分别存 `cameraLimit`、`userLimit`、`formatLimit`，并记录每次裁剪的阶段与数量。
- False Colour 原有导出用途保留明确模式；不得在用户只开启预览叠层时悄悄写进普通 LUT。图表/取样默认 CPU 指定阶段。
- 图像 alpha 先按像素格式解预乘，再处理颜色，最后预乘；alpha=0 不除零，隐藏 RGB 的策略明确。CPU 数值路径和系统屏幕渲染路径分别验收。
- Core Image 工作/输入/输出色彩空间显式配置，Log 图像不能先当 sRGB 自动解码。具体适配参见 [Apple 工作色彩空间接口](https://developer.apple.com/documentation/coreimage/cicontextoption/workingcolorspace)。

## 7. 可直接交给实现者的验收数据

[数值夹具](../tests/fixtures/native-contracts/numeric-contracts.json)包含：12 个范围换算点、27 个 3³ 网格节点、非对称矩阵及精确逆、六个四面体轴序、对角线相等点、与三线性不同的结果、0.9 标度、非交换曝光/偏移及内存字节数。

其来源是有理数精确推导脚本，不调用旧 JS，也不调用待测 Swift。复跑：

```sh
python3 tools/native-validation/generate-contract-fixtures.py
```

这些是开发夹具，不是厂商 LUT 或 App 资源；不能将夹具导入 `LUTCatalog`。它们只锁定基础契约，不代替所有真实曲线、cubic、HDR、调节与全管线的精度验收。


### 2.1.4 Black Gamma 输出编码版本（2026-10-02）

阶段 15 在输出编码之后、范围映射之前独立逐通道执行，支持 1D，不使用 RGB 灰轴替代三维耦合。参数来自旧 `twk-blkgam.js` 与 `lutSlider.testData` 的硬数值范围：`upperStops∈[−9,2]`、`featherStops∈[0,9]`、`power∈[0.01,10]`；不强制旧界面的步长量化。

- 阈值准备使用 scene 灰 `0`、`0.18*2^(upperStops−featherStops)`、`0.18*2^upperStops`。启用 CDL 时只执行其独立 SOP，然后输出编码，并按旧 `getLumVals` 的 `0.2126/0.7152/0.0722` 加权为 B／L／U；不用工作空间 Y，不经过曝光、Multitone、SDR 或色域矩阵。启用黑白电平时，对上述加权阈值应用阶段 14 准备好的仿射映射；Knee 启用时独立 SOP 后由同一个阶段 13 编码器执行 Knee，再加权，已有独立契约。
- 对 `B<x≤U`，计算 `c=B+(U−B)*((x−B)/(U−B))^power`。若 `x>L` 且 `x>c`，计算 `t=((x−L)/(U−L))²`，输出 `t*x+(1−t)*c`；其他有效分支输出 c。区间外原样保留。不 clamp 负值／超白。零羽化不会进入除零分支；折叠或反转阈值按旧区间条件旁路。
- 核心公式与阈值在相同编码单位下使用。正仿射 Legal↔Data 换算可同时作用于输入、阈值和结果；研发旧参照保留原单位，不能直接把 Legal 阈值喂给 Data 输入。现有 `.linearScene` 是 scene 值语义，不冒充旧 Null 特殊模式。
- `lutcalc.black-gamma-output-encoded.v1` 保留旧 Double 运算次序。新默认 `lutcalc.black-gamma-output-encoded-stable.v1` 保留相同连续公式，在次正规比值处用 `exp(power*log(x−B)+(1−power)*log(U−B))` 避免先舍入比值；power=1 精确保留输入。两种版本明确保存，不自动改写版本。
- 最小次正规数和 power=0.01 的旧兼容结果对独立 70 位 Decimal 偏差约 `8.24e-8`，超过 `2e-12`。此不等价边界公开保留；默认稳定版本对同一点通过原门槛。不能称旧兼容版本在全部 Double 参数域达到了连续公式精度。
- 配置从 schema 7 起保存；旧原生 schema 1–6 缺字段为 nil。未知键／版本／参数拒绝，disabled 仍保存身份。没有新增 UI 控件。

实际失败、位模式复现、高精度参照和当前验收状态见[Black Gamma 阶段记录](native-validation/2026-10-02-black-gamma.md)。完整输出链和平台运行仍未完成。

### 2.1.5 黑白电平 Legal 仿射版本（2026-10-02）

`lutcalc.black-highlight-legal-affine.v1` 逐通道执行阶段 14，位于输出编码之后、Black Gamma 与最终范围映射之前。用户黑位／高光映射参数是 Legal IRE 数值，参考白 `highReferenceScene` 是 scene reflectance（默认 0.9）；禁止将参考白当作 stop 或输出 code。

- 默认锚点为 scene 黑 0 与参考白，经过独立 CDL SOP／Knee 或普通输出编码，然后按旧 `0.2126/0.7152/0.0722` 加权，不使用工作空间 Y。曝光、色域矩阵、Multitone 和 SDR 不进入默认值准备链。
- 准备 `A=(highMap−blackMap)/(highDefault−blackDefault)`、`B=blackMap−A*blackDefault`，逐通道输出 `A*x+B`。输入、默认锚点与已换算的映射值须在同一编码单位。不 clamp 负值／超白；允许负斜率与零斜率，零参考跨度、溢出或非有限值明确失败。
- 黑位／高光映射有限且大于 −0.073，无人为上限；参考白有限且大于 0。未勾选相应调节时用该端默认值。锁定值始终采用；未锁定值与默认值相差不超过旧 `0.0001` 时按自动默认值处理。此阈值属于原功能语义，不是数值验收容差。
- `rebasedForChanges` 处理输出曲线／CDL／HDR 变化，清除未锁定的旧映射；参考白变化只清除未锁定高光值。`nil` 表示自动默认，生成计划不读取编辑历史或全局标志。输出曲线和 CDL 更新 helper，以及文稿输出 gamma 参数更新接入此规则；仅输出色域变化、输入曲线变化、曝光变化不重置映射。CDL 饱和度本身不改变独立 SOP 锚点。
- 对原生 normalized Data code 曲线（相机 log 及 ACESproxy）使用固定 `876/1023`、`64/1023` 将 Legal 参数换到原生单位；原生 canonical signal／scene 曲线在自身规范单位执行。该换算与最后的输出 video 范围／位深独立。旧近似小数常量与精确换算的差异须用真实旧链计量，不能直接混用两个单位。
- 本版本不实现旧 Null 特殊旁路；`.linearScene` 对应 scene reflectance，不能拿它冒充 Null。Knee 准备依赖已接入；完整 HDR/OOTF 参数与全部旧变体准备仍需单独闭合。
- 阶段 14 的准备结果也作用于 Black Gamma 的 B／L／U 阈值，再执行阶段 15。1D 同样适用，不使用灰轴近似 3D 耦合。
- 字段从原生 schema 8 起保存，原生 schema 1–7 缺字段为 nil；锁定、自动值与算法身份进入不可变请求、撤销快照和项目包。没有新增 UI 控件。

先行契约、32 组实际旧默认值重置、独立 Decimal／全网格、实际旧组合链与未覆盖范围见[黑白电平阶段记录](native-validation/2026-10-02-black-highlight.md)。


### 2.1.6 Knee 输出 Hermite 旧兼容版本（2026-10-02）

`lutcalc.knee-output-hermite.v1` 位于阶段 13，替代普通输出编码；输入使用 legacy linear（scene/0.9），曲线准备和中间结果使用 Legal IRE，再换回当前输出曲线的原生编码单位。普通编码的计算次序保留；Knee 关闭或低于阈值时直接返回原生编码结果，避免无效单位往返。

- 参数硬范围为 `startStops∈[−5,8]`、`clipStops∈[0.05,8]`、`clipSlope∈[0,2.5]`、`smoothness∈[0,1]`，均须有限且 start<clip。默认 `.05/6/.25/1/legal=true`。不强制界面步长量化，不迁移旧 App 设置文件。
- `f(stop)` 为当前输出曲线将 `2^stop/5` legacy linear 编码到 Legal；这里不执行 CDL。最大起点保留旧 `j=8; j>0; j-=0.1` 的 Double 迭代，首个 `f(j)≤.95`，找不到时将旧 false 比较行为明确表达为上限 0。有效起点取原参数和该上限较小者，阈值为 `.2*2^start`。
- CDL 启用时，clip 灰 `.2*2^clip` 只执行三通道独立 SOP，再按 `.2126/.7152/.0722` 加权；有效 clip 为 `log(Y/.2)/log(2)`。不用饱和度或工作空间 Y。非正／非有限 Y、零有效跨度明确失败，不复制旧 NaN→0 或除零行为；有效跨度为负导致起点导数为负时，保留旧禁用 Knee 的分支，使用普通编码。
- 两段 Hermite 的起点为 `f(start)`，终点 Legal 为 `.99`、extended 为 `959/876−.01`。起点导数保留 `±.001` 差分与跨度，末端 slope 为 `clipSlope/100`；中点和中点导数按旧 `.5/.501/.499` 准备，各导数再除 2。保留旧中点限值、第一段导数根判断和 fallback split 公式，不补写成另一条曲线。
- 低于阈值使用普通编码；阈值至 clip 用两段 Hermite 与直线按 smoothness 混合；clip 以上按末端 slope 外推。1D 保持独立通道，不 clamp 负值／超白。
- **旧版本不保证整体单调。** 原代码省略第二段导数根检查；Rec709、start=1、clip=6、clipSlope=0 的第二段独立 70 位导数最小值约 `−.001043441669496352`。300 组旧参数调查中 20 组出现下降；保留原算法身份和最小复现，不将该曲线用于声称唯一反求。若后续引入单调版本，须另立算法身份及独立参照。
- 黑白电平默认值／Black Gamma 阈值用独立 CDL SOP→同一个 Knee/输出编码器→固定亮度加权；黑白电平再映射 Black Gamma 阈值。不递归创建调节计划，不重复应用 Knee。Knee 编辑保留锁定／显式映射；自动 nil 锚点在新计划重新准备，旧输出／CDL／HDR 重置规则保持。
- 配置从 schema 9 起保存，原生 schema 1–8 缺字段为 nil；参数、disabled、算法身份、不可变请求和撤销快照保留。未知字段、身份错配、无效参数拒绝。

实际命令、独立 Hermite 基函数 Decimal 参照、完整 33³/65³、旧现有组合链与未覆盖范围见[Knee 阶段验收](native-validation/2026-10-02-knee.md)。


### 2.1.7 Highlight Gamut 输出混合旧兼容版本（2026-10-02）

`lutcalc.highlight-gamut-output-blend.v1` 替代阶段 10 普通输出色域转换；输入必须是 Sony S-Gamut3.cine 工作空间 linear，不能先执行普通输出矩阵后再重复做 Highlight Gamut。即使输入／输出色域相同，也须先进入工作空间。算法使用 Double 和原色/CAT 矩阵，不使用颜色采样表。

- 配置保存 `highlightSpace` 稳定 ID、`transition`、`lowStops`、`highStops`、enabled 和算法身份。线性／对数过渡都保存 stop 锚点。默认 `low=0, high=2.3219`，保留旧初始值的四位小数；不将旧数值输入框的显示整数或步长强加到核心。finite 且 low<high；`2^stop/5` 的两个 legacy 阈值须有限、正、可区分，溢出／下溢和折叠明确拒绝。
- 同一工作空间输入独立经普通输出矩阵得到 B，经高光输出矩阵得到 H。**旧 Y 是工作空间亮度系数点乘 B，而非普通输出色域的物理 Y。** 输出使用两组 RGB 坐标的数值混合，不再将 H 反转回普通输出空间；此旧行为由算法身份明确隔离，不能称作标准亮度保留或标准色域压缩。
- Y≥high 阈值输出 H；Y≤low 输出 B（负值／非正 Y 不执行对数）。过渡区线性权重 `r=(high−Y)/(high−low)`，对数权重 `r=(highStops−log(Y*5)/log(2))/(highStops−lowStops)`；逐通道 `r*B+(1−r)*H`。不添加 clamp 或末端饱和度修正。
- scene 输入／输出经 `.9` 标度与 legacy linear 衔接；普通输出线性 SDR 阶段 11 继续在阶段 10 之后，Knee／输出编码在 13。黑白电平／Black Gamma 的独立 gamma 默认值准备不包含 Highlight Gamut、色域矩阵或曝光。
- 这是 3D 耦合阶段；核心独立 1D 和 1D 请求在写文件前拒绝。不能用灰轴采样冒充完整 1D 表达；disabled 才允许其余条件合格的 1D 请求。
- 当前可引用原生目录中 14 个矩阵色域，并使用当前 CIECAT02/Bradford。其余旧特殊空间／自定义色域／非矩阵输出与其他 CAT 仍按原范围待补，不把内置风格表搬入产品。矩阵旧 `lc/lf` 一致的证明不推广到非矩阵预览链。
- 参数从 schema 10 起保存，原生 schema 1–9 缺字段为 nil；disabled 仍记录身份，配置进入不可变请求、撤销与项目包，gamma 编辑和其他 settings helper 不得丢失。未知字段／色域／身份错配拒绝。文稿 gamma 后端的字段保留不属于 UI 验收。

先行契约、原色与 CAT 的独立高精度参照、完整网格、实际旧组合链和未覆盖范围见[Highlight Gamut 阶段验收](native-validation/2026-10-02-highlight-gamut.md)。

### 2.1.8 Gamut Limiter 双阶段旧兼容版本（2026-10-02）

`lutcalc.gamut-limiter-chroma-span.v1` 保留阶段 12 的线性限制／辅助样本准备与阶段 17 的 Post Gamma 限制。它按通道跨度压缩颜色，不是将每个分量上限设为用户 level。参数 `linearStops` 有限且在 `[-6,6]`，对应旧线性阈值 `2^linearStops`（参考白为 1，不乘 `.2`）；`postLevel` 有限且在 `[.01,1.09]`，单位为 Legal IRE。次级空间可省略，或与输出相同而不建立辅助样本；`protectBoth` 决定只保护次级或两者同时保护。

- Linear 模式在阶段 12 将主输出各通道钳到零，再从该值按输出→Sony S-Gamut3.cine→次级的两次矩阵操作计算次级值。保留两次乘法的舍入，不预合并矩阵。scene 与旧 linear 使用 `.9` 标度；阶段 17 不执行。
- Post Gamma 模式在阶段 12 不钳零、不修改主样本，从原始值计算并保存次级 linear。阶段 17 将次级依次经过与主路径**相同的输出曲线／Knee、黑白电平、Black Gamma**；完整旧链还要求相同的阶段 16 显示转换，SDR 分支现已同样接入阶段 16，四个 HDR/OOTF 显示变体依赖保持未完成。
- Post Gamma 的主编码值转换到 Legal IRE 后钳零，次级编码值不钳零。normalized Data 曲线用 `876/1023` 和 `64/1023` 换算，canonical signal／scene 沿用各自既有单位约定；限制后换回 native code，范围映射仍在阶段 19。
- `span=max(R,G,B)−min(R,G,B)`；无次级选择主 span，仅保护次级选择次级 span，同时保护选择两者最大。`q=span/level`，仅 `q>1` 时输出 `Y+(channel−Y)/q`，其中 Y 系数来自普通输出空间原色矩阵。旧主空间分支额外检查 max>level；非负主分量下 span>level 已蕴含该条件。
- 辅助样本属于一次不可变请求的局部计算，不在多个节点或任务之间共享。溢出、缺失必要辅助值和非有限结果明确失败，定位阶段 12 或 17。参数缺失／disabled 保留此前数值行为；启用后拒绝 1D 生成，不能用灰轴代替耦合颜色变换。
- 原生字段从 schema 11 起保存，原生 schema 1–10 缺字段为 nil；未知键、未知算法、色域身份错配及旧 schema 偷带字段拒绝。disabled 仍保存身份，文稿 gamma 后端和 settings helper 保留配置及快照，不属于 UI 验收。

契约、独立有理数原色／70 位 Decimal、完整网格、真实旧组合链与未覆盖范围见[Gamut Limiter 阶段验收](native-validation/2026-10-02-gamut-limiter.md)。

### 2.1.9 输出码值单位修复与历史策略（2026-10-02）

准备显示转换时发现，先前 `hasNormalizedDataEncoding` 漏列了 19 个实际已带 Data 包装的输出：CIE L*、ProPhoto、BBC 0.4/0.5/0.6、BBC WHP283 400/800 和 γ1.5–γ2.6。普通输出函数已返回 `Legal*0.85630498533724+0.06256109481916`，旧元数据却令 Kernel 将其当作未包装数值。该缺陷会污染 Knee 的 Legal 准备／输出、黑白电平 Legal 映射及 Post Gamma Limiter 主／次级换算；单独普通编码的返回值未改变。

- 新请求默认 `native.output-code-units.complete.v2`。19 个旧 Data 包装使用其实际舍入常数恢复 Legal；原有 15 个 Data 曲线保持其 `876/1023`、`64/1023` 边界，剩余 10 个 canonical／scene／参数化曲线保持既有单位。不能依据函数名字决定单位。
- 黑白电平与 Knee 共用同一不可变输出编码器的 scale/offset，Post Gamma 主／次级也用该边界；不再另写不完整的曲线分支。不改变普通编码函数、网格、位深、插值或 `2e-12`。
- 历史 `native.output-code-units.partial.v1` 仅用于复现先前原生项目：19 个遗漏家庭仍按 scale=1、offset=0 准备。它是已知有缺陷的兼容身份，不满足这组 Legal 契约的正确性要求，不能作为新增全量数值通过证据。
- γ2.2、scene 黑 0、锁定 black Legal `.05` 的最小复现：历史结果 `.05`，正确 native Data 为 `.05*.85630498533724+.06256109481916`，即 `.105376344086022`。两者差异不通过放宽误差解释。
- 原生 schema 12 从 settings／algorithmVersions 显式保存相关策略；schema 1–11 对受影响输出明确迁移到 partial v1，以保持原重开结果，读取不改写源文件。其余输出维持原行为。选择 complete v2 是明确版本变化，不默默替换历史结果。旧 schema 偷带新字段、未知策略、缺失必要身份和策略／版本错配拒绝。
- 两种策略均进入不可变请求、文稿 gamma 后端与 settings helper、磁盘项目、撤销／重做及计划版本。没有新增 UI；历史项目切换到新策略的交互仍待后续重做。

真实先行失败、19 曲线独立参照、全部 33³/65³ 节点及文件验收见[输出单位修复记录](native-validation/2026-10-02-output-code-units.md)。这不是阶段 16 显示转换已经实现的证明。


### 2.1.10 SDR 显示转换（2026-10-02）

- 稳定算法身份 `lutcalc.display-sdr-decode-matrix-encode.v1`。这是生成管线阶段 16 的数值算子，不是屏幕预览或 UI 改造。
- 保留旧 Display Colourspace Converter 的 23 个 SDR 曲线定义和 7 个显示色域：Rec.709、Rec.2020、sRGB、P3 DCI／D60／D65、ProPhoto D50。显示色域独立于主转换目录，不把 P3 伪装为 Rec.2020；trace 保存独立 DisplayGamut 身份。
- 用户显式选择基础／目标曲线及色域。阶段 16 将当前 carrier 按所选 OutputCodeUnitPolicy 还原为 Legal IRE，再基础曲线解码→矩阵→目标曲线编码，恢复同一 carrier 后进入原有阶段 17／19。不能自动改用主输出曲线作为解码定义。历史 partial v1 的单位缺陷仍有独立身份，兼容使用不声称正确性通过。
- 3D 矩阵由公开原色／白点通过固定 CAT02 和 SGamut3cine 中间空间推导，不拷贝旧矩阵采样表；与主计划用户选择的 CAT 独立。基础和目标显示色域相同时跳过矩阵。旧 1D 路径仅转换曲线，跳过矩阵，所选不同显示色域仍保存，不改为灰轴 3D 取样。
- 显示曲线保留旧 buffer 分段规则。BBC 0.4／0.5／0.6 逆函数使用严格 `>`，不能复用采用 `>=` 的标量方法；ProPhoto 的阈值采用原 Double 幂公式，不能用数学上相等但位型不同的字面量替代。负值与超白不额外 clamp；溢出定位阶段 16。
- 阶段 16 在 Black Gamma 后、Post Gamma Gamut Limiter 前。次级限制数据也经过相同显示转换，不重复黑白电平或 Black Gamma。限制器继续保留旧主输出色域的 Y 系数，不以显示目标色域系数悄悄改变旧定义。黑白电平与 Black Gamma 的默认锚点不加入显示转换。
- 项目字段从 schema 13 起；原生 schema 1–12 缺字段为 nil。参数、disabled 和算法身份进入项目、不可变请求与撤销快照。严格键、未知曲线／色域／版本、身份错配和旧 schema 偷带字段拒绝。
- 四个旧 HDR 显示变体（PQ OOTF、HLG OOTF、HLG、PQ EOTF Only）及其参数依赖保持未完成，不能以标准 PQ／HLG 别名代替。

契约、独立误差与最终平台状态见[SDR 显示转换阶段记录](native-validation/2026-10-02-display-conversion.md)。完整调节链、HDR、设备运行及全量发布仍需各自验收。


### 2.1.11 False Colour 原生阈值版本（2026-10-02）

- 身份 `lutcalc.false-colour-native-thresholds.v1`，usage 显式为 `exportLUT`；不新增或隐式启用预览叠层。schema 14 保存算法、开关和可空参数，旧原生 schema 1–13 缺失为 nil。disabled 和全部标记关闭仍保存配置；活跃三通道分类的 1D 请求在写文件前拒绝。
- 阶段 05 在工作空间／曝光之后、白平衡与 PSST/CDL 之前保存 band，不改 RGB；阶段 18 在主／次级 Gamut Limiter 后用同一 band 覆盖。不能按最终调节图像重算 Y。Y 系数从 S-Gamut3.cine／D65 原色白点按旧余因子运算顺序推导；scene 除以 0.9 换旧线性单位。
- 保留旧首个 `Y<=threshold` 与末端修正规则、Purple／Blue 低端联动、Yellow 开启且 Red 关闭时的固定 5.95 stop 上边界。blue≥1、yellow∈[.0001,3]、red≥3.5，均有限；blue／red 无人为上限，prepared 溢出拒绝，下溢 0 保留。nil fallback blue6.1／yellow.26／red5.95 与显式默认6.1／.5／6 分开保存。
- 六个 Green／Pink／Orange 九位小数端点和七种 Legal RGB 是旧告警区间／标签的定义参数，不是厂商 LUT 或等价采样表，不称物理色彩管理。标记按当前输出 carrier 包装；未标记原 Double 保留，不反复换算。trace 保存 band，覆盖后 colourSpace／DisplayGamut 为 nil；未包装混合数值标为 `diagnosticPaletteMixed`，非标准输出色域线性信号。
- Apple `pow` 与 V8 在部分 stop 上相差 1 ULP，离散分类会显著不同。11,328 个旧输入中 192 个差异完整保留；80／120 位独立 Decimal 最小复现与本版本一致。原生完整网格和边界按独立定义验证，不能把更换版本后的输出当成未修正旧输出逐位通过，更不能用 `2e-12` 隐藏颜色类别差异。
- False Colour 不改变前面 Knee／黑白电平／Black Gamma／Display 的默认锚点，且不旁路其数值失败。旧 Null、完整限幅政策、V8 特定 fdlibm 舍入的逐位兼容、任意 stop 全域／跨设备数值仍未验收。

先行失败、最小复现、独立分类与四个完整 33³/65³、两条实际旧 17³ 组合链和存储／文件／任务结果见[False Colour 阶段记录](native-validation/2026-10-02-false-colour.md)。数值门槛仍为 `2e-12`，完整调节链与全量发布不因此完成。


### 2.1.12 Final Output 格式边界与用户限幅（2026-10-02）

- 身份 `lutcalc.final-output-code-limits.v1`，阶段 19 显式配置。schema 15 保存 algorithm／enabled／mode／clipLegal／minimumCode10／maximumCode10／forceBlackLegal；schema 1–14 缺失为 nil，仍走既有原生范围路径，不静默改变历史输出。disabled 同样保存算法身份，但不准备算子。
- 范围为 normalized 10-bit 格式定义，不随项目 rangeBitDepth 改写。模式 none／both／blackOnly／whiteOnly；none 仍应用格式上下限。默认格式上下界 0／67025937，来源为旧格式约束，不是 LUT 表。有限反转上下限允许，保留旧 `min(maximum,max(minimum,value))`，不排序上下界。
- Legal 输出格式下限为 `(bClip−64)/876`，forceBlackLegal 时为 0；上限 `(wClip−64)/876`。Data 下限为 `bClip/1023`，forceBlackLegal 时为 `64/1023`；上限 `wClip/1023`。若用户限幅启用，在 Legal 输出或 clipLegal=false 时按选中模式收紧到 0／1；否则 Data 收紧到 `64/1023`／**`959/1023`**，不能改为 940。
- 阶段 19 先将当前 carrier 还原为 Legal IRE，Data 输出执行 `(value*876+64)/1023`，Legal 输出保持值，再夹到准备边界。范围结果标记 encodedData／encodedVideo。独立单通道支持 1D，不取灰轴代替其他三通道耦合算子。
- HDR 无 Display 时还须收紧到准备的 mxO；Data 采用旧常量 `mxO*.85630498533724+.06256109481916`。核心可验证显式独立 HDR 上下文；计划对活跃 PQ／HLG 新政策在缺完整峰值模型时明确抛出 hdrLimitUnavailable，不以标准曲线别名猜值。已有 SDR Display 激活时按旧规则跳过 HDR cap，但不能声称 HDR 显示变体已经实现。
- 所有准备量、输入、中间换算须有限；溢出定位 stage19，任务中止并取消暂存提交。不同于旧引擎可能把 Infinity 夹成有限结果，原生禁止限幅隐藏计算失败。旧 Null、cameraLimit／userLimit／formatLimit 的完整独立来源与逐阶段裁剪计数、完整 HDR 自动参数仍欠。

先行失败、独立 Decimal／完整网格、旧组合链及项目／文件／任务证据见[Final Output 阶段记录](native-validation/2026-10-02-final-output.md)。精度门槛保持 `2e-12`，这不是完整 FULL-04 或全量发布通过。


### 2.1.13 精确曝光组（2026-10-02）

身份 `native.exposure-batch-rational.v1`。minimum／maximum 为整数 stop，subdivisions 为 1–4；第 i 点为 `(minimum*subdivisions+i)/subdivisions` 的一次 Double 换算，不反复累加近似步长。端点包含，零使用正零。每项以 withExposureStops 替换基础请求的曝光，其余曲线／色域／范围／调节／最终限幅和用户 LUT 保留；没有因批量调整网格、位深、插值或阈值。

旧正常选择 64 组／864 点全部冻结并逐项对照，名称保持两位 stop 小数以 p 替换小数点，零为 0-Native；名称精度不作为计算精度。三分之一 stop 的新／旧累加差异以独立 80 位 Decimal 验证，不称逐位兼容。真实 CUBE 读回覆盖七个 17³ 曝光文件，以及 0、1/3、2/3、1 stop 各完整 33³／65³，共 3,829,917 通道；独立误差与平台状态见[曝光批量阶段记录](native-validation/2026-10-02-exposure-batch.md)。相机 ISO/EI 三类政策另见[规则复核](native-validation/2026-10-02-camera-exposure-research.md)，不能自动把 ISO 比例加到本批次。

## 2026-10-02 接续：Log C scene 显式 EI 接线

`arri.logc-sup2-scene-published.v1`／`arri.logc-sup3-scene-published.v1` 分别使用公开 SUP 2／3 的 scene exposure 紧凑式。`ARRILogCSceneSettings` 必须显式保存算法身份和文档列出的离散 EI（160、200、250、320、400、500、640、800、1000、1280、1600），输入／输出互相独立。缺参、算法错配、额外载荷和不支持 EI 拒绝；无 EI 800 回退、参数插值、传感器裁剪或接缝修补。

阶段 2 解码到 scene reflectance，阶段 13 和 Knee／黑白电平／Black Gamma 的输出锚点共用准备好的不可变输出内核。原始编码单位为 Data，Legal 换算采用 `876/1023` 和 `64/1023`；最后生成保持 Double、完整网格和 `2e-12`。公开参数接缝与相机 shoulder 误差另见[研究记录](native-validation/2026-10-02-logc3-shoulder-research.md)，不能以实现误差代替真实相机准确度。

sensor signal 仍通过独立 `ARRILogCCompact` API 表达，不将其黑电平和线性单位当作 scene reflectance。此包不提供 SUP 2 raw camera RGB 的默认色域，也没有新增相机默认预设；同空间显式载体的测试不证明相机色域映射。AWG3、sensor 生成语义、相机 EI 政策和高 EI shoulder 继续待完成。UI 暂缓。


## 2026-10-02 接续：AWG3 和显式 EI 预设

`arri.awg3.v1` 由 ARRI 公开原色／D65 白点推导 Double XYZ／RGB 矩阵，保留负原色和域外 RGB，不使用舍入后的六位 XYZ 矩阵或采样资源。SUP 3 scene 的 11 个预设明确保存 EI、Data→Data、曝光 0和 CAT02，不为缺参请求默认 EI800；SUP 2 raw 不自动映射为 AWG3。计划身份保存所有输入／输出／高光／次级 AWG3 引用。

独立有理数 CAT02／Bradford 与 80／120位 Decimal参照覆盖60矩阵、675840彩色全码通道及四配置的完整33³/65³，保持2e-12。工作空间trace记录实际阶段3／4矩阵路径，不改变数值顺序。完整相机和shoulder未完成；结果见[阶段记录](native-validation/2026-10-02-awg3.md)。
