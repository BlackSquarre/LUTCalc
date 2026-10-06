# ICC mAB/mBA section offset 顺序审计

## 审计范围

本轮只审计 ICC `mAB `/`mBA ` 与 `mpet` 的 section offset 是否还需要增加物理地址顺序约束，不扩大元素支持范围，也不改变用户导入 profile 的兼容策略。

## 当前实现

解析器校验每个非零 offset 位于 payload 内、四字节对齐，并以 offset 表中下一个更高地址作为当前 section 的边界。重复 offset 只有在语义允许共享 section 时保留；重叠但不完全共享的范围拒绝。`mpet` 另校验元素表、元素输入输出维度和执行链维度。

## 结论

ICC 字段的语义顺序是 B、Matrix、M、CLUT、A（`mAB `）或相应反向管线，但当前公开资料不足以证明所有合法 profile 都必须把这些 section 按该语义顺序物理递增排列。若仅凭字段顺序强制 `offsetB < offsetMatrix < offsetM < offsetCLUT < offsetA`，可能拒绝把 section 放在不同物理顺序、但各 offset 与 section 边界均自洽的合法用户 profile。

因此本轮不新增物理顺序拒绝规则，也不伪造“完整 ICC offset 语义已闭合”的结论。

## 最小复现与未覆盖

可构造一个 `mAB ` payload：五个 offset 均四字节对齐且各 section 不重叠，但将 A、CLUT 的物理写入顺序交换；现有解析器仍按 offset 计算边界并依据字段选择 section。要把该构造判为非法，需要 ICC 公开条款或独立实现（如 ColorSync/LittleCMS）对物理顺序的明确拒绝证据；本轮未取得该证据。

未覆盖真实第三方 profile 的逐码参照、全部 MPE 元素、BPC、gamut mapping 和 ColorSync 语义。Goal 继续 `active`。

