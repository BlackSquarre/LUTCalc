# 原生基础契约夹具

用途：供未来 Swift 测试读取，不进入 App 运行资源。本目录中的 `.cube` 是合成解析样例，有些故意非法，不是厂商 LUT。

- `numeric-contracts.json`：由 Python Fraction 精确有理数推导后舍入为 Double 的基础预期；公式与布局见[数值契约](../../../docs/native-swift-numeric-contracts.md)。
- `parser-contracts.json`：8 个文件的接受/拒绝要求与错误类别，见[格式契约](../../../docs/native-swift-runtime-contracts.md)。`huge-dimension.cube` 必须在分配前失败。
- `sha256.json`：冻结数据内容的校验值。更新夹具需有数学/规格变更依据，不能因为实现失败而重写预期。

重新生成：`python3 tools/native-validation/generate-contract-fixtures.py`。
交叉验证：`node tools/native-validation/verify-contract-fixtures.js`。

矩阵采用 row-major 存储、列向量乘法；节点 R 最快。插值输入都在单位 cube 内，含负值/HDR 的**输出**，不代表已经定义域外 cubic 行为。测试解析器时不要对本目录全部 CUBE 运行“必须合法”的资料归档检查。
