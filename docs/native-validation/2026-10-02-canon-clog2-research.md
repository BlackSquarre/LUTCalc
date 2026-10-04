# Canon C-Log2/Cinema Gamut 来源与范围

## 固定来源

本包使用 ACES 仓库提交 `29b722bccd529460696a8382394504cae2e88419` 的两个 CTL 文件。文件保存在 `research/colour/2026-10-02-canon-clog2/`，提交号和 URL 记录在同目录 `sources.json`。实现前会补录两个文件的 SHA-256；URL、提交号和本地字节必须同时核对。

CTL 给出 Canon C-Log2 与 Cinema Gamut 到 ACES2065-1 的公开解析式。Cinema Gamut 原色为 R `(0.7400, 0.2700)`、G `(0.1700, 1.1400)`、B `(0.0800, -0.1000)`，白点 D65 `(0.3127, 0.3290)`；到 ACES AP0 使用 CAT02。公开方向先将 C-Log2 解码为线性，再乘 `0.9`；反向方向先除以 `0.9` 再编码。

## 旧兼容方向

旧 `js/gamma.js` 的 C-Log2 参数为 `[0.045164984, -0.006747091156, 0.241360772, 87.09937546, 10, 0.092864125, 1, 0, -0.006747091156]`。它作为独立 legacy TransferID 保存，不能与公开 CTL 的 `0.9` 场景标度混用。C-Log 和 C-Log3 没有在本包中借用 C-Log2 公式，Canon CP IDT 仍保持未实现和拒绝。

## 本包不证明的内容

这项工作只覆盖解析式、Cinema Gamut 原色、CAT02 矩阵、TransformPlan 和已有 C-Log2 身份的默认映射。它不证明全部 Canon 机型、连续 EI、真实高 EI shoulder、sensor 生成单位、C-Log/C-Log3、CP IDT、目标软件往返或 UI。
