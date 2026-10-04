# 色彩技术资料归档

采集日期：2026-09-23。**仅限研发参照，不得加入原生 App 或运行依赖。**

结论与待办见[覆盖调查](../../../docs/colour-research-2026-09-23.md)及[纯算法审计](../../../docs/algorithm-only-audit.md)。本目录保存原文，原始资料的语言与格式保持不变；新增说明使用中文。

## 1. 当前内容

- 登记 48 个下载来源：42 个成功，6 个未取得。成功文件约 54.7 MiB（未含解包副本）。
- 直接取得 9 份 PDF、9 个 ZIP、2 个 CUBE、20 份网页、2 份官方 API 文本。
- 解包得到 28 份参考文件：7 份 PDF、15 份 CUBE、2 份 CTL、2 份 DCTL、1 份 CLF、1 份 DCTLE。两个 OM 包中的数据表内容相同，不能按文件数算独立规范数。
- 已校验文件哈希、ZIP CRC、PDF 签名、CUBE 尺寸与有限数值；结果见 [archive-validation.json](archive-validation.json)。这些检查不证明色彩准确度。

## 2. 索引和使用方法

| 内容 | 文件/目录 |
| --- | --- |
| 下载计划与官方 URL | [sources.json](sources.json) |
| 获取状态、最终 URL、时间、大小与 SHA-256 | [download-manifest.json](download-manifest.json) |
| 归档成员原名、父 ZIP 哈希与解包文件哈希 | [extraction-manifest.json](extraction-manifest.json) |
| 当前 JS 运行注册表与源文件哈希 | [current-inventory.json](current-inventory.json) |
| 独立 PDF / 资料包 / 官方 LUT | `whitepapers/`、`packages/`、`official-luts/` |
| 参考源码与解包结果 | `reference-code/`、`extracted/` |
| 官方页面与 PDF 检索文本 | `pages/`、`text/` |

`text/` 是 `pdftotext -layout` 的辅助检索结果。公式中的根号、上下标、分段次序须回到原始 PDF 核验；已经视觉核对 O-Log2 解码页与 I-Log 公式页。下载代码仅供阅读，本轮未执行 CTL、DCTL、DCTLE 或网页生成器。

从仓库根目录执行：

```sh
node tools/research/snapshot-colour-inventory.js
python3 tools/research/fetch-colour-sources.py fuji-flog2c-pdf
python3 tools/research/extract-colour-sources.py
python3 tools/research/verify-colour-archive.py
```

下载器只需要 Python 标准库，解包工具的 PDF 文本提取另需 `pdftotext`。下载器无参数会处理全部登记项，已下载且哈希相同的文件复用缓存。本轮小米/vivo 的 Python TLS 请求失败后，使用保持证书校验的 `curl --http1.1` 成功下载，已记录传输方式与原错误。

## 3. 全部来源

| ID | 官方来源 | 本地文件 / 状态 |
| --- | --- | --- |
| `fuji-flog2c-pdf` | [F-Log2 C 数据表 1.0](https://dl.fujifilm-x.com/support/lut/F-Log2C_DataSheet_E_Ver.1.0.pdf) | [whitepapers/fuji-flog2c-v1.pdf](whitepapers/fuji-flog2c-v1.pdf) |
| `fuji-flog2-pdf` | [F-Log2 数据表 1.1](https://dl.fujifilm-x.com/technical-data/F-Log2_DataSheet_E_Ver.1.1.pdf) | [whitepapers/fuji-flog2-v1.1.pdf](whitepapers/fuji-flog2-v1.1.pdf) |
| `fuji-flog2c-ctl` | [F-Log2 C 官方 CTL IDT 1.10](https://dl.fujifilm-x.com/support/lut/FUJIFILM_IDT_F-Log2C_Ver.1.10.ctl.zip) | [reference-code/fuji-flog2c-ctl-v1.10.zip](reference-code/fuji-flog2c-ctl-v1.10.zip) |
| `fuji-flog2c-clf` | [F-Log2 C 官方 CLF IDT 1.10](https://dl.fujifilm-x.com/support/lut/FUJIFILM_IDT_F-Log2C_Ver.1.10.clf.zip) | [reference-code/fuji-flog2c-clf-v1.10.zip](reference-code/fuji-flog2c-clf-v1.10.zip) |
| `leica-llog-v1.6` | [Leica L-Log 参考手册 1.6](https://leica-camera.com/sites/default/files/pm-118912-L-Log_Reference_Manual_V1.6.pdf) | 未取得：HTTP Error 502: Bad Gateway |
| `insta-ilog10` | [Insta360 10-bit I-Log 白皮书](https://wassets.insta360.com/common/31f0330509384b7b8ba0a07f4ff4eb13/Insta360_10-bit_I-Log_White_Paper.pdf) | [whitepapers/insta360-ilog10.pdf](whitepapers/insta360-ilog10.pdf) |
| `xiaomi-aces` | [小米官方 ACES 资料包](https://cdn.alsgp0.fds.api.mi-img.com/e-commerce/global/Mi-Log_ACES%20Profiles.zip) | [packages/xiaomi-aces.zip](packages/xiaomi-aces.zip) |
| `oppo-olog-pdf` | [OPPO O-Log 白皮书 V1](https://www.oppo.com/content/dam/oppo_com/en/mkt/footer/OPPO_O-Log_Profile_WhitePaper_V1.pdf) | [whitepapers/oppo-olog-v1.pdf](whitepapers/oppo-olog-v1.pdf) |
| `om-log400-2020` | [OM-1 II OM-Log400 BT.2020 官方 LUT](https://support.jp.omsystem.com/en/support/imsg/digicamera/download/software/3dlut/files/om1m2_LUT_OM-Log400_BT.2020_to_WDR_BT.709_v1.0.zip) | [official-luts/om-log400-2020.zip](official-luts/om-log400-2020.zip) |
| `om-log400-p3` | [OM-1 II OM-Log400 P3-D65 官方 LUT](https://support.jp.omsystem.com/en/support/imsg/digicamera/download/software/3dlut/files/om1m2_LUT_OM-Log400_P3-D65_to_WDR_BT.709_v1.0.zip) | [official-luts/om-log400-p3.zip](official-luts/om-log400-p3.zip) |
| `samsung-page` | [Samsung Log 官方说明与下载入口](https://developer.samsung.com/mobile/samsung-log-video.html) | [pages/samsung-log.html](pages/samsung-log.html) |
| `oppo-page` | [OPPO O-Log/O-Log2 下载入口](https://www.oppo.com/cn/log-to-rec709-download/) | [pages/oppo-log.html](pages/oppo-log.html) |
| `leica-page` | [Leica SL3-S 官方下载页](https://leica-camera.com/de-CH/fotografie/kameras/sl/sl3-s-schwarz/downloads) | [pages/leica-downloads.html](pages/leica-downloads.html) |
| `kine-spec` | [KineLOG3 与 Kinefinity Wide Gamut 技术说明](https://kinefinity.com/support/guides/kinelog3-technical-specifications) | [pages/kine-spec.html](pages/kine-spec.html) |
| `gopro-log` | [GoPro GP-Log2 说明](https://gopro.github.io/labs/log/) | [pages/gopro-log.html](pages/gopro-log.html) |
| `gopro-generator` | [GoPro GP-Log2 官方生成器源码页面](https://gopro.github.io/labs/gplog2/) | [reference-code/gopro-gplog2.html](reference-code/gopro-gplog2.html) |
| `acescct` | [ACEScct 官方规范](https://docs.acescentral.com/encodings/acescct/) | [pages/acescct.html](pages/acescct.html) |
| `aces-rgc` | [ACES 参考色域压缩规范](https://docs.acescentral.com/rgc/specification/) | [pages/aces-rgc.html](pages/aces-rgc.html) |
| `zcam-page` | [Z CAM 官方资源页](https://www.z-cam.com/resources/) | 未取得：HTTP Error 403: Forbidden |
| `honor-page` | [荣耀 Magic-Log 官方 LUT 下载页](https://www.honor.com/cn/phones/rec-lut-download/) | [pages/honor.html](pages/honor.html) |
| `vivo-page` | [vivo 官方支持入口](https://www.vivo.com/my/support/questionList?categoryId=10906) | [pages/vivo.html](pages/vivo.html) |
| `fuji-page` | [富士技术资料官方入口](https://www.fujifilm-x.com/global/support/download/technical-data/) | [pages/fuji.html](pages/fuji.html) |
| `om-page` | [OM System 官方 LUT 表](https://support.jp.omsystem.com/jp/support/cs/soft/3dlut/3dlutdl.html) | [pages/om.html](pages/om.html) |
| `xiaomi-page` | [小米 ACES 官方入口](https://www.mi.com/global/product/aces/) | [pages/xiaomi.html](pages/xiaomi.html) |
| `samsung-pdf` | [Samsung Log 官方白皮书](https://developer.samsung.com/Mobile/file/24767859-feda-461f-8f2b-f3b547822874) | 未取得：Response is not a PDF |
| `samsung-linear` | [Samsung Log 官方线性参考 LUT](https://developer.samsung.com/Mobile/file/03cb55a3-a7b8-485d-8de7-1a6b5f2a19fd) | 未取得：Official download redirects to Samsung account sign-in; HTML rejected |
| `samsung-rec709` | [Samsung Log 官方 Rec.709 参考 LUT](https://developer.samsung.com/Mobile/file/12a52a67-175d-4f8e-acb5-d7f32e636e07) | 未取得：Official download redirects to Samsung account sign-in; HTML rejected |
| `oppo-olog2-pdf` | [OPPO O-Log2 白皮书 V1](https://www.oppo.com/content/dam/oppo_com/cn/mkt/footer/oppo-o-log2-whitepaper_cn_v1.pdf) | [whitepapers/oppo-olog2-v1.pdf](whitepapers/oppo-olog2-v1.pdf) |
| `oppo-olog2-aces` | [OPPO O-Log2 ACES 工作流资料 V2](https://www.oppo.com/content/dam/oppo_com/cn/mkt/footer/O-Log2_ACES_Workflow_Guide_CHN_V2.zip) | [packages/oppo-olog2-aces.zip](packages/oppo-olog2-aces.zip) |
| `oppo-olog2-tools` | [OPPO O-Log2 官方转换工具 V1](https://www.oppo.com/content/dam/oppo_com/cn/mkt/footer/o-log2-technical-transform-tools_v1.zip) | [packages/oppo-olog2-tools.zip](packages/oppo-olog2-tools.zip) |
| `oppo-olog-tools` | [OPPO O-Log 官方转换工具 V0](https://www.oppo.com/content/dam/oppo_com/cn/mkt/footer/o-log-technical-transform-tools_v0.zip) | [packages/oppo-olog-tools.zip](packages/oppo-olog-tools.zip) |
| `leica-llog-v1.9` | [Leica L-Log 参考手册 1.9](https://leica-camera.com/sites/default/files/pm-37826-L-Log_Reference_Manual_V1.9.pdf) | [whitepapers/leica-llog-v1.9.pdf](whitepapers/leica-llog-v1.9.pdf) |
| `honor-log-v1` | [荣耀 Magic-Log 第一组官方 LUT](https://www.honor.com/content/dam/honor/cn/rec-lut-download/img/honor_logv1_rec709_v3_33.cube) | [official-luts/honor-log-v1.cube](official-luts/honor-log-v1.cube) |
| `honor-log-v2` | [荣耀 Magic-Log 第二组官方 LUT](https://www.honor.com/content/dam/honor/cn/rec-lut-download/img/honor_new_logv2_rec709_v9.cube) | [official-luts/honor-log-v2.cube](official-luts/honor-log-v2.cube) |
| `vivo-aces` | [vivo Log 官方 ACES 资料包](https://asia-exstatic-vivofs.vivo.com/PSee2l50xoirPK7y/1786436739858/resource/vivo-Log_ACES_Profiles.zip) | [packages/vivo-aces.zip](packages/vivo-aces.zip) |
| `bt1886` | [ITU-R BT.1886 标准](https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.1886-0-201103-I%21%21PDF-E.pdf) | [whitepapers/itu-bt1886.pdf](whitepapers/itu-bt1886.pdf) |
| `bt2020` | [ITU-R BT.2020-2 标准](https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2020-2-201510-I%21%21PDF-E.pdf) | [whitepapers/itu-bt2020-2.pdf](whitepapers/itu-bt2020-2.pdf) |
| `bt2380` | [ITU-R BT.2380 电视色度参数报告](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2380-2015-PDF-E.pdf) | [whitepapers/itu-bt2380.pdf](whitepapers/itu-bt2380.pdf) |
| `aces-output` | [ACES 2 输出变换架构](https://docs.acescentral.com/system-components/output-transforms/) | [pages/aces-output.html](pages/aces-output.html) |
| `apple-log2` | [Apple Log2 官方 API 定义](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog2) | [pages/apple-log2.html](pages/apple-log2.html) |
| `dji-luts` | [DJI 官方 LUT 与设备列表](https://www.dji.com/lut) | [pages/dji-luts.html](pages/dji-luts.html) |
| `sony-workflow` | [Sony CineAlta 工作流指南](https://pro.sony/s3/2024/11/29133636/Sony_CineAlta_WF_Guide_v1.0.pdf) | 未取得：HTTP Error 403: Forbidden |
| `sigma-bf` | [Sigma BF 官方规格](https://www.sigma-global.com/en/cameras/bf) | [pages/sigma-bf.html](pages/sigma-bf.html) |
| `nikon-zr` | [Nikon ZR 官方规格](https://www.nikonusa.com/p/zr/2006/overview) | [pages/nikon-zr.html](pages/nikon-zr.html) |
| `apple-log2-text` | [Apple Log2 官方 API 文本](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog2.md) | [pages/apple-log2.txt](pages/apple-log2.txt) |
| `apple-p3-text` | [Display P3 官方定义](https://developer.apple.com/documentation/coregraphics/cgcolorspace/displayp3.md) | [pages/apple-p3.txt](pages/apple-p3.txt) |
| `sony-profile` | [Sony 相机曲线与 HLG1/2/3 说明](https://helpguide.sony.net/ilc/2410/v1/en/contents/0412D_picture_profile.html) | [pages/sony-profile.html](pages/sony-profile.html) |
| `panasonic-logc3` | [Panasonic LogC3 扩展说明](https://av.jpn.support.panasonic.com/support/global/cs/dsc/download/fts/enhance/gh6_gh7/index.html) | [pages/panasonic-logc3.html](pages/panasonic-logc3.html) |
| `nikon-nlog-specification` | [Nikon N-Log 规格文档 1.0.0](https://download.nikonimglib.com/archive3/hDCmK00m9JDI03RPruD74xpoU905/N-Log_Specification_(En)01.pdf) | [whitepapers/nikon-nlog-v1.pdf](whitepapers/nikon-nlog-v1.pdf)、[text/nikon-nlog-v1.txt](text/nikon-nlog-v1.txt) |

## 4. 已知限制

- Samsung 三个文件入口跳转账号登录。曾返回的 HTML 已拒绝并清除，没有以 `.cube` 文件冒充有效 LUT。
- Leica 1.6 旧链接失败，但已取得 1.9（2026 年 6 月）；Z CAM 资源页、Sony 工作流 PDF 请求返回访问错误。
- Apple 官方 API 文本仅用于确认颜色空间定义，完整 Log 2 白皮书未取得。
- vivo 包含加密 `.dctle`，不能将其列作公开可读解析实现。
- OPPO 官方白皮书与参考代码的分段/常数存在差异；小米文字与公式存在对数底数措辞差异。详细裁决待办见覆盖调查第 5 节。
- 原始资料归各自权利人所有。此归档用于项目研究与测试；不自动视为允许随 App 或其他公共发行物再分发。
- 当前尚无原生 App target；“不进入安装包”已经写入设计与发布门槛，实际工程完成后仍必须验证。
