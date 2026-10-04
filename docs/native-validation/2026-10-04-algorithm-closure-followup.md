# 2026-10-04 算法闭合后续核验

## 范围

本轮只处理已有原生算法的契约核验和台账同步，不新增厂商曲线、色域、查表替代或 UI 范围。用户界面、iPad 交互和追加真机性能按当前决定暂缓。

## 1D LUT 分析聚合属性

`IndependentChannelAnalysis.isInvertibleBySingleValue` 的生产实现已明确要求红、绿、蓝三个通道都严格单调。既有实现已经包含三个通道判断；本轮补充了聚合属性契约，防止只看单通道报告的回归。

先行定向命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testIndependent1DChannelsReportStrictFlatAndReversalWithoutChangingSamples'
```

实际结果：

- 退出码 `0`。
- 定向测试 1 项，0 失败。
- 测试日志：`/tmp/lutcalc-analysis-aggregate-contract-20261004.log`。
- 日志 SHA-256：`c770301eae9bbf0b26db2b037e4951a9b193f57dc84e4cbda09366dcaf188789`。
- 蓝通道含反转时，整体 `isInvertibleBySingleValue` 明确为 `false`；输入样本未被修改。

## 全量 Swift Release 回归

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  2>&1 | tee /tmp/lutcalc-algorithm-closure-full-release-20261004.log
```

实际结果：

- 8 个测试包全部通过：LUTSharedUI `162`、LUTProject `64`、LUTPreview `94`、LUTJobs `67`、LUTFormats `56`（其中既有外部夹具 2 项按设计跳过）、LUTCore `230`、LUTCatalog `24`、LUTAnalysis `32`。
- 失败数为 `0`；实际测试总数按测试包汇总为 `729`，LUTFormats 的 2 项跳过保持原规则。
- LUTAnalysis 的 `ImportedLUTAnalysisContractsTests` 共 7 项通过。
- 日志 SHA-256：`77ee8f253bbbc5417739ddc5806d6f805dbd9c71af2b0cbfaff8ccf4f415a66f`。

## 现有解析式批量回归

```sh
python3 tools/native-validation/run-check-batch.py \
  Native/Packages/LUTKit/.build/out/Products/Release --workers 2 \
  2>&1 | tee /tmp/lutcalc-algorithm-batch-20261004-r2.log
```

实际结果：退出码 `0`，Rec.709、S-Log3、LogC4、V-Log、Apple Log／Log 2、Rec.2100 HLG、BT.1886 共 7 个独立检查全部通过。日志 SHA-256 为 `da79f406521ef8ca90111aa4e9ba41d9065c8f3c720b53176808cbf0763bea47`。

## 查表台账与 JSON 语法

`docs/native-validation/2026-10-04-lut-replacement-inventory.md` 继续冻结 9 个 `.labin` 资源和 45 个直接查表注册。当前没有任何一项取得公开连续定义、适用范围和独立全域参照，因此替代计数仍为 `0/9` 与 `0/45`；禁止复制、压缩、拟合或改格式后打入 Swift。

```sh
python3 -m json.tool \
  docs/native-validation/artifacts/2026-10-04-camera-default-availability/default-availability.json
```

实际结果：退出码 `0`。相机默认路由 JSON 语法有效；本轮不改动 legacy `34/66`、published `41/66` 的已冻结统计。

## 未闭合范围

本轮没有关闭 DJI DLog-M、45 个直接查表注册、9 个 `.labin`、Canon CP IDT、RED DRAGONColor2／IPP2、ARRI SUP2 raw 冲突、PQ OOTF 语义冲突、完整 HDR／ICC／LUTAnalyst 或完整相机模型。缺少公开定义的项目继续保留最小复现和研究阻塞；Goal 仍保持 active。
