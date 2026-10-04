# 既有 N-Log／Cineon 公式参照归档

日期：2026-10-04。本目录只为本仓库已有两条传递曲线的原生迁移提供独立参照，不增加产品范围。

- `colour-nikon-nlog.py` 与 `colour-cineon.py`：固定 Colour Science commit `ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5` 的原始公开源码，仅阅读公式与来源，未引入 App 或运行依赖。
- `ocio-nuke-default-make.py`：固定 Sony Imageworks OpenColorIO-Configs commit `c0ff0e96574e823606a81e62e3867d9d8ba238db`；第 161–164 行是 Cineon black-offset 解码式。研究过程只提取公开公式，没有运行该脚本生成采样表，也没有移植其 `FileTransform` 运行方式。
- `manifest.json` 保存实际获取时间、URL、commit、字节数与 SHA-256，并逐项声明 `runtime_allowed=false`。
- Nikon 官方 PDF 与检索文本保存在 `research/colour/2026-09-23/whitepapers/nikon-nlog-v1.pdf` 和 `text/nikon-nlog-v1.txt`；公式第 2 节、BT.2020/D65 定义第 3 节。

官方 N-Log 使用 650／452；旧 LUTCalc 使用 650.1864339／451.7887494 且其方法接受灰 0.2 的 legacy 线性域。原生保持不同算法 ID，不用旧公式代替官方公式。Cineon 公开 black-offset 公式与旧负值线性 toe 同样区分；公开公式无定义的负值输出拒绝，不自动裁剪。

90 位 Decimal 全码、真实旧 JS 对照、单位／项目／网格／编译验收见 `docs/native-validation/2026-10-04-camera-transfer-algorithms.md`。这些来源不会随 App 或公共安装包分发。

## Sony S-Log／S-Log2 补充来源

- `colour-sony.py` 固定 Colour Science 同一 commit 的 Sony S-Log、S-Log2、S-Log3 解析函数和 S-Gamut 原色；只提取解析式与参数。
- `sony-aces/IDT.Sony.SLog2_SGamut_Daylight_10i.ctl` 与 `12i.ctl` 固定 ACES dev commit，保存 Sony 提供的 S-Log2 daylight IDT 作为独立代码参照。该 IDT 还包含 ACES 矩阵和 10/12 位量化边界；本实现只闭合标量传递函数，色温特定 IDT 与完整 ACES 工作流仍单独验收。
- 上述文件均标记 `runtime_allowed=false`，不会打包进入 App。
