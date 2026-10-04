# H12 旧设置文件调查

日期：2026-09-23。状态：调查完成；旧设置导入尚未实现。

## 实际格式

旧版 `js/lutgeneratebox.js` 的保存按钮调用 `messages.getSettings()`，扩展名为 `.lutcalc`。`js/lutmessage.js` 的 `getSettings()` 以 `JSON.stringify` 生成单个 JSON 文件，其根字段包括 `version`，以及各 UI 模块写入的 `lutBox`、`gammaBox`、`tweaksBox`、`generateBox`、`formats`、`cameraBox`。新原生 `.lutcalc` 是含 `manifest.json` 与可选 `Resources/` 的目录项目包，入口与结构不同；应先判别文件/目录，再选择对应解析路径。

| 旧字段来源 | 保存内容 | 当前原生清单状态 |
| --- | --- | --- |
| `js/lutlutbox.js:getSettings` | 1D/3D、网格尺寸、输入输出 legal、裁剪、缩放、位深、设备选项 | 仅 3D 网格、输入输出范围和部分域可表达；其余不能静默丢弃 |
| `js/lutgammabox.js:getSettings` | 输入输出曲线与色域的显示名称、线性曲线及对比度等 | 原生只登记少量稳定 ID；需逐名映射且核对算法版本，不可按数组序号或近似名称替换 |
| `js/luttweaksbox.js:getSettings` | 调节开关及各调节子项 | 原生变换计划尚无完整调节链 |
| `js/lutcamerabox.js:getSettings` | 厂商、型号、shift | 原生相机预设尚未完整登记 |
| `js/lutformats.js:getSettings` 与 `js/lutgeneratebox.js:getSettings` | 输出格式选择及文本精度 | 原生项目清单尚未完整保存格式预设和精度策略 |

## 后续约束

旧文件解析应作为独立、只读的纯 Swift 导入路径，生成已映射项与未映射项报告；只有全部影响输出的字段可表示且算法来源已验证时，才允许创建新项目。旧源文件保持不变；未知字段、未知版本、厂商 LUT 依赖与无法判断的默认值均报告，不能用当前默认值代替。此调查没有实施转换，也没有声称旧项目可打开。

本次仅检查仓库源文件，没有改动旧引擎或夹具。实际命令为 `rg -n 'getSettings|setSettings|saveSettings|loadSettings|\.lutcalc' js --glob '!**/*combined*'` 和逐段读取上述函数；没有执行旧文件导入。所查源码的 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `js/lutgeneratebox.js` | `7ee0ccc830f8f8920d83f65542a5c879f4cb22590775014edb28a9307ea0923f` |
| `js/lutmessage.js` | `bd712784c1aee8990aaeabbf4324f9df0fc3b2d9f5aa5e34e7bcf6447caf0a8c` |
| `js/lutlutbox.js` | `c63db842b8585b2d8949c0bb7b0ef36b854b2573490a4b0d55682ac03eda8a60` |
| `js/lutgammabox.js` | `3b55bba6e97c95eb812eb1f53ba016ef760d53172861add4fa4a746ba0b3e0b6` |
| `js/luttweaksbox.js` | `dcaec3c4f8ed77d6432b2017e15967a4a7da7189723f87eb36b7b79b4b755665` |
| `js/lutcamerabox.js` | `77d734241d39dc9a1c5d892cfbba8a5432eda5ec1a8ff05a7f69d94f381d5a2a` |
| `js/lutformats.js` | `f197be83d3071f927ff682be9970b4efdddb94e8eddea11b466df14118c46dab` |

平台、真机和旧文件实样验证均未完成。
