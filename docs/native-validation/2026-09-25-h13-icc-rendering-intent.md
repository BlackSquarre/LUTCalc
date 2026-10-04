# H13 ICC rendering intent 头部元数据阶段验收

日期：2026-09-25。Goal 仍 active。本阶段只读取 ICC profile header 的 rendering intent，不执行显示转换，也不改变 Double 取样或 LUT 生成。

## 契约与实现

依据 ICC profile header 的固定字段布局，offset 64 的大端 UInt32 只接受 0–3，并在 `ICCProfileValidation.renderingIntent` 中保留。未知值拒绝为 `invalidRenderingIntent`；该字段只是来源元数据，不会选择或隐式执行色彩管理策略。

`PreviewContractsTests` 覆盖 0、1、2、3 四个合法枚举值和未知值 4 的拒绝。实现只修改 `ICCProfile.swift` 与预览契约测试，未改变 ICC tag payload、采样表或显示编码。

## 定向 Release 验证

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter PreviewContractsTests.testICCProfileRenderingIntentUsesHeaderEnumAndRejectsUnknownValue
```

结果：1 项通过，退出码 0。当前阶段未宣称完整 ICC 类型覆盖、工作空间/显示转换、Core Image/Metal 或 HDR/EDR 完成。

## 状态

H13 仍未完成。完整 ICC 语义、真实色彩管理、双端运行、真机和 Files 验证继续保留。
