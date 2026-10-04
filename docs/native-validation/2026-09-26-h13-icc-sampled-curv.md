# H13 ICC 用户 sampled `curv` 子段验收

日期：2026-09-26

## 范围

在既有 ICC RGB matrix/TRC CPU 子集中，支持用户提供 profile 的 `curv(count>1)` uInt16 均匀采样曲线。解码在相邻输入节点间线性插值；编码检查各区间的候选解，并拒绝无解或多解。实现使用 Swift `Double`，不把样本移入产品目录、App 资源或其他硬编码数组。

公开资料：ICC.1:2022-05 <https://www.color.org/specification/ICC.1-2022-05.pdf> 的 `curveType` 规定 count 为 0、1、多个节点时的不同表示及 uInt16 数值域；本阶段只对多节点形式执行均匀节点间线性插值，并保留原节点精度。

仍只支持 `RGB `/`XYZ `、`rXYZ/gXYZ/bXYZ/wtpt` 矩阵 tag 和三个通道 TRC。该功能不会自动改变图像显示解释，不建立通用 ICC 工作空间或链接变换。

## 契约与实现

- `curv(count=0)` 仍为恒等；`count=1` 仍将 u8Fixed8 gamma 转成 `Double`。
- `count>1` 必须与已验证的条目数相等，且所有 uInt16 归一化样本有限并在 `[0,1]` 内；输入编码域仍限定 `[0,1]`。
- 通过 `x * (count - 1)` 确定均匀表区间，线性插值得到曲线输出，不对样本表作重采样、平滑或单调修补。
- 反向逐区间解析线性段候选。平段上的目标值、反转/重叠产生的多个候选返回 `nonUnique`；没有候选返回 `outsideDomain`。端点共享产生的同一输入解会去重。
- 逆向候选只保留首个解，发现第二个不同解即失败，避免为大 profile 再分配与节点数等长的候选数组。
- 单个 profile 仍受 `ICCProfileValidator.maxProfileBytes = 16 MiB` 限制。仅对用户输入 profile 解码其曲线数据；没有厂商 LUT、旧 `.labin` 或研发夹具进入 App。

## 先失败后通过的定向测试

新增 3 项 `ICCMatrixTRCContractsTests`：

1. uInt16 量化采样曲线按均匀节点作线性插值，并检查反向恢复输入；对照值由测试中的样本表直接逐段计算，检查容差 `2e-5` 只覆盖 uInt16 曲线量化。
2. 33³ 和 65³ RGB 网格经 RGB→XYZ→RGB 往返；最大绝对误差须小于 `2e-12`。
3. 对精确平台段和非单调重叠曲线，反向操作均须报告 `nonUnique`，不得任选分支。

开发期定向验证发现，既有 `count=2` 拒绝断言与新增支持范围冲突，且首轮独立插值预期值未按正确区间计算。测试修正为规范区间的显式样本对照，并把两点曲线用例更新为接受路径；最终定向命令：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests
```

结果：14 项通过。日志 `/tmp/lutcalc-icc-sampled-targeted.log`，SHA-256：`2b04d045ed4e82c32e2910b36f19275d13bccf107a587f7b77183f73a74beab6`。

## 完整回归与平台构建

```text
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 0。各测试 target 汇总 302 项执行、0 失败；2 项既有可选参考样本按原测试设计跳过。最终日志 `/tmp/lutcalc-icc-sampled-swift-final2.log`，SHA-256：`296136b11a6b130fcf0fe93876361bc70d0f91104903a688bd71996931730d0c`。

```text
bash tools/native-validation/verify-native-release.sh
```

使用 Xcode `27.0 (27A266a)`、Swift 6、macOS 27.0 SDK 与 iOS/iOS Simulator 27.0 SDK。Node 11 项、Python 8 项、7 个公式独立检查、54 个 33³/65³ CUBE 生成/独立读回对及 H08/H09/H10/H12/H13 命令行契约均通过；macOS、iOS Simulator、iOS generic Release 构建成功，3 个 App 包资源审计通过。入口最终退出码 2，唯一报告为缺少真实全量清单 `docs/native-validation/full-scope-acceptance.json`；未生成该清单。

最终发布入口日志 `/tmp/lutcalc-icc-sampled-release-final.log`，SHA-256：`1c1fd261903dbda2c35a0f895778c31a222662b7233d19e72cafcd75847ca52d`。

本阶段没有测量网格误差以外的独立相机参照，没有声称提高既有颜色转换准确度。表格插值的定义和候选/歧义测试证明的是实现所选 ICC sampled curve 语义，不是 profile 厂商语义或显示效果验收。

## 源码哈希

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTPreview/ICCMatrixTRCTransform.swift` | `07a526572fa8a42c2eea3ab4c04432c8015f00274471796db74bc1a4b46fe47d` |
| `Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMatrixTRCContractsTests.swift` | `d6e30066b895d409f5380027957452258eb066624d69a0ee48ceb61584443b1d` |

`ICCProfile.swift` 本阶段未更改。夹具和阈值没有修改。

## 未覆盖范围

ICC `mft1/mft2`、`mAB/mBA`、设备链接与色彩管理策略、ICC sample curves 超出已验证矩阵/TRC 路径的语义、Core Image/Metal 对照、HDR/EDR、真机图像/ICC 文件导入均未覆盖。三平台构建与资源审计不等于真机运行或发布就绪。H13、FLOW-05、UI-03 和全量迁移继续未完成。
