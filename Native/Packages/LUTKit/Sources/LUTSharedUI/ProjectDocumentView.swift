import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
import LUTCore
import LUTFormats
import LUTCatalog
import LUTAnalysis
import LUTJobs
import LUTProject

public struct ProjectDocumentView: View {
    @Environment(\.scenePhase) private var scenePhase
    private static let catalog: AlgorithmCatalog? = try? AlgorithmCatalog.builtIn()
    private static let catalogPresets: [PresetDescriptor] =
        catalog?.presets ?? []
    private static let catalogTransfers: [TransferDescriptor] =
        catalog?.transfers ?? []
    private static let catalogColorSpaces: [ColorSpaceDescriptor] =
        catalog?.colorSpaces ?? []
    @Binding private var document: LUTProjectDocument
    private let fileURL: URL?
    @State private var exposureDraft: String
    @State private var gammaEditor: ParameterizedGammaEditorContext?
    @State private var inputError: String?
    @State private var exportSession = ProjectExportSession()
    @State private var exportFormat = FileLUTFormat.cube
    @State private var sampleSession = ProjectSampleSession()
    @State private var userLUTSession = UserLUTImportSession()
    @State private var showImageImporter = false
    @State private var showLUTImporter = false
    @State private var confirmedSource = false
    @State private var sampleXDraft = "0"
    @State private var sampleYDraft = "0"
    @State private var sampleError: String?
    @State private var lutRedDraft = "0.5"
    @State private var lutGreenDraft = "0.5"
    @State private var lutBlueDraft = "0.5"
    @State private var lutSampleError: String?
    @State private var lutInterpolation = LUTInterpolation.tetrahedral
    @State private var lutSampleSection = UserLUTSampleSection.primary
    @State private var grayAxisReport: GrayAxisReport?
    @State private var grayAxisError: String?
    @State private var structureError: String?
    @State private var inverseRedDraft = "0.5"
    @State private var inverseGreenDraft = "0.5"
    @State private var inverseBlueDraft = "0.5"
    @State private var inverseError: String?
    @State private var showStoredLUTExporter = false
    @State private var storedLUTExportDocument = LUTProjectDocument.StoredUserLUTExport(
        suggestedFilename: "exported-lut", bytes: Data())
    @State private var showGeneratedLUTExporter = false
    @State private var generatedLUTExportDocument = GeneratedLUTExportDocument.emptyPlaceholder
    @State private var generatedLUTSaveResult: String?

    public init(document: Binding<LUTProjectDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        _exposureDraft = State(initialValue: String(document.wrappedValue.manifest.settings.exposureStops))
    }

    public var body: some View {
        DocumentNavigationContainer {
            Form {
                Section("项目") {
                    LabeledContent("名称", value: fileURL?.lastPathComponent ?? "未命名项目")
                    Text("由系统文档界面管理打开和保存。")
                        .foregroundStyle(.secondary)
                    Picker("转换预设", selection: Binding(
                        get: { currentPresetID },
                        set: { setPreset($0) }
                    )) {
                        Text("项目当前设置").tag("custom")
                        ForEach(Self.catalogPresets, id: \.id) { preset in
                            Text(preset.id).tag(preset.id)
                        }
                    }
                    Text("选择预设会替换转换参数；项目尺寸、输入域和资源保持。")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("撤销") { changeHistory(undo: true) }
                            .disabled(!document.canUndo)
                            .accessibilityHint("撤销最近一次项目设置修改")
                            .keyboardShortcut("z", modifiers: [.command])
                        Button("重做") { changeHistory(undo: false) }
                            .disabled(!document.canRedo)
                            .accessibilityHint("重做最近一次已撤销的项目设置修改")
                            .keyboardShortcut("z", modifiers: [.command, .shift])
                    }
                }
                Section("输入") {
                    Picker("曲线", selection: Binding(
                        get: { document.manifest.settings.inputTransfer },
                        set: { setInputSelection(transfer: $0, space: document.manifest.settings.inputSpace) }
                    )) {
                        ForEach(Self.catalogTransfers, id: \.id) { descriptor in
                            Text(algorithmLabel(descriptor.aliases, fallback: descriptor.id.rawValue))
                                .tag(descriptor.id)
                        }
                    }
                    .accessibilityIdentifier("inputTransferPicker")
                    Picker("色域", selection: Binding(
                        get: { document.manifest.settings.inputSpace },
                        set: { setInputSelection(transfer: document.manifest.settings.inputTransfer, space: $0) }
                    )) {
                        ForEach(Self.catalogColorSpaces, id: \.id) { descriptor in
                            Text(algorithmLabel(descriptor.aliases, fallback: descriptor.id.rawValue))
                                .tag(descriptor.id)
                        }
                    }
                    Text("曲线和色域来自原生注册表；公式来源与验证范围记录在项目资料中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(document.manifest.settings.inputGamma == nil
                           ? "设置自定义输入 Gamma" : "编辑自定义输入 Gamma") {
                        gammaEditor = ParameterizedGammaEditorContext(
                            slot: .input, revision: document.revision)
                    }
                    Picker("输入范围", selection: Binding(
                        get: { document.manifest.settings.inputRange },
                        set: { setInputRange($0) }
                    )) {
                        Text("Data").tag(SignalNormalization.data)
                        Text("Legal / Video").tag(SignalNormalization.video)
                    }
                    .accessibilityIdentifier("inputRangePicker")
                }
                Section("变换") {
                    HStack {
                        TextField("曝光档数", text: $exposureDraft)
                            .onSubmit { commitExposure() }
                            .accessibilityLabel("曝光档数")
                            .accessibilityHint("输入有限的 Double 曝光档数，提交后写入项目")
                        Button("应用曝光") { commitExposure() }
                            .accessibilityHint("提交当前曝光档数")
                    }
                    Picker("范围位深", selection: Binding(
                        get: { document.manifest.settings.rangeBitDepth },
                        set: { setRangeBitDepth($0) }
                    )) {
                        ForEach([8, 10, 12], id: \.self) { depth in
                            Text("\(depth) 位").tag(depth)
                        }
                    }
                    Picker("白点适应", selection: Binding(
                        get: { document.manifest.settings.adaptation },
                        set: { setAdaptation($0) }
                    )) {
                        Text("CIE CAT02").tag(ChromaticAdaptation.cieCAT02)
                        Text("Bradford").tag(ChromaticAdaptation.bradford)
                    }
                    if let inputError { Text(inputError).foregroundStyle(.red) }
                }
                Section("输出") {
                    Picker("目标", selection: Binding(
                        get: { currentOutputMode },
                        set: { setOutputMode($0) }
                    )) {
                        Text("线性 ACES AP0").tag(OutputMode.linearAP0)
                        Text("DJI D-Log2 / D-Gamut2").tag(OutputMode.dlog2DGamut2)
                        Text("项目当前目标").tag(OutputMode.custom)
                    }
                    Picker("曲线", selection: Binding(
                        get: { document.manifest.settings.outputTransfer },
                        set: { setOutputSelection(transfer: $0, space: document.manifest.settings.outputSpace) }
                    )) {
                        ForEach(Self.catalogTransfers, id: \.id) { descriptor in
                            Text(algorithmLabel(descriptor.aliases, fallback: descriptor.id.rawValue))
                                .tag(descriptor.id)
                        }
                    }
                    .accessibilityIdentifier("outputTransferPicker")
                    Picker("色域", selection: Binding(
                        get: { document.manifest.settings.outputSpace },
                        set: { setOutputSelection(transfer: document.manifest.settings.outputTransfer, space: $0) }
                    )) {
                        ForEach(Self.catalogColorSpaces, id: \.id) { descriptor in
                            Text(algorithmLabel(descriptor.aliases, fallback: descriptor.id.rawValue))
                                .tag(descriptor.id)
                        }
                    }
                    Picker("输出范围", selection: Binding(
                        get: { document.manifest.settings.outputRange },
                        set: { setOutputRange($0) }
                    )) {
                        Text("Data").tag(SignalNormalization.data)
                        Text("Legal / Video").tag(SignalNormalization.video)
                    }
                    .accessibilityIdentifier("outputRangePicker")
                    Button(document.manifest.settings.outputGamma == nil
                           ? "设置自定义输出 Gamma" : "编辑自定义输出 Gamma") {
                        gammaEditor = ParameterizedGammaEditorContext(
                            slot: .output, revision: document.revision)
                    }
                    Picker("3D 尺寸", selection: Binding(
                        get: { document.manifest.cubeSize },
                        set: { setCubeSize($0) }
                    )) {
                        ForEach(Array(Set([17, 33, 65, document.manifest.cubeSize])).sorted(), id: \.self) { size in
                            Text("\(size)³").tag(size)
                        }
                    }
                    .accessibilityIdentifier("cubeSizePicker")
                    Picker("导出格式", selection: $exportFormat) {
                        Text("CUBE").tag(FileLUTFormat.cube)
                        Text("SPI3D").tag(FileLUTFormat.spi3d)
                        Text("SPI1D").tag(FileLUTFormat.spi1d)
                        Text("3DL Flame / Assimilate").tag(FileLUTFormat.threeDL)
                        Text("ILUT Resolve 14-bit 1D").tag(FileLUTFormat.ilut)
                        Text("OLUT Resolve 12-bit 1D").tag(FileLUTFormat.olut)
                        Text("Assimilate LUT 1D").tag(FileLUTFormat.lut)
                        Text("VLT Varicam 17³").tag(FileLUTFormat.vlt)
                    }
                    .accessibilityIdentifier("exportFormatPicker")
                    .disabled(exportSession.exportStatus == .running)
                    if exportFormat == .spi1d {
                        Text("SPI1D 输出 1024 点独立通道曲线；跨色域项目会拒绝生成。")
                            .foregroundStyle(.secondary)
                    }
                    if exportFormat == .spi3d && document.manifest.domain != .unit {
                        Text("SPI3D 只支持单位输入域；当前项目域导出时会报错。")
                            .foregroundStyle(.secondary)
                    }
                    if exportFormat == .threeDL {
                        Text("3DL 使用 10-bit 输入、12-bit 输出；仅支持单位域和 0 到 1 的输出值。")
                            .foregroundStyle(.secondary)
                    }
                    if exportFormat == .ilut {
                        Text("ILUT 输出 16384 点、14-bit 独立通道；要求同色域、单位输入域及 0 到 1 的输出值。")
                            .foregroundStyle(.secondary)
                    }
                    if exportFormat == .lut {
                        Text("Assimilate LUT 输出 4096 点三通道整数块；要求同色域、单位输入域及可表示码值。")
                            .foregroundStyle(.secondary)
                    }
                    if exportFormat == .vlt {
                        Text("VLT 仅支持单位域、17³ 和 0 到 1 的 12-bit 输出值。")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("生成 \(exportFormat.rawValue.uppercased())") { startExport() }
                            .accessibilityIdentifier("generateLUTButton")
                            .disabled(exportSession.exportStatus == .running)
                        if exportSession.exportStatus == .running {
                            Button("取消") { exportSession.cancel() }
                                .accessibilityIdentifier("cancelLUTButton")
                        }
                    }
                    Text(statusText)
                        .foregroundStyle(statusIsError ? .red : .secondary)
                        .accessibilityIdentifier("exportStatus")
                        .accessibilityLabel("导出状态")
                        .accessibilityValue(statusText)
                    if let lastExport = exportSession.lastExport {
                        Button("保存到文件…") {
                            prepareGeneratedLUTExport(lastExport)
                        }
                        ShareLink(item: lastExport.url) {
                            Label("分享或保存 \(lastExport.url.pathExtension.uppercased())",
                                  systemImage: "square.and.arrow.up")
                        }
                        Text("导出请求版本 \(lastExport.revision)，\(lastExport.writtenNodes) 个节点")
                            .font(.caption)
                    }
                    if let generatedLUTSaveResult {
                        Text(generatedLUTSaveResult)
                            .accessibilityIdentifier("generatedLUTSaveResult")
                    }
                }
                Section("图像数值取样") {
                    Button("导入图像") { showImageImporter = true }
                    Text("数值取样与屏幕预览分开；预览使用 CPU Double 参考路径并单独转换到 sRGB。")
                        .foregroundStyle(.secondary)
                    switch sampleSession.loadStatus {
                    case .idle: EmptyView()
                    case .running: ProgressView("正在解码图像…")
                    case .loaded:
                        if let image = sampleSession.image, let url = sampleSession.imageURL {
                            LabeledContent("文件", value: url.lastPathComponent)
                            LabeledContent("尺寸与位深", value:
                                "\(image.width) × \(image.height)，每通道 \(image.bitsPerComponent) 位")
                            LabeledContent("解码色彩空间", value: image.decodedColorSpaceName ?? "未标明")
                            LabeledContent("源文件嵌入 ICC", value:
                                image.colorSpaceProvenance == .sourceEmbeddedICC
                                    ? (image.sourceEmbeddedICCProfileName ?? "已证实") : "未证实")
                            LabeledContent("解码空间 ICC 资料", value:
                                image.decodedICCProfile == nil ? "无" : "有（可能由 ImageIO 推断或指定）")
                            Toggle("我确认按当前项目输入曲线和色域解释原始 RGB 码值", isOn: $confirmedSource)
                            HStack {
                                Button("生成屏幕预览") {
                                    sampleSession.startDisplayPreview(
                                        document: document, confirmedSource: confirmedSource)
                                }
                                .disabled(!confirmedSource || sampleSession.displayStatus == .running)
                                if sampleSession.displayStatus == .running {
                                    Button("取消预览") { sampleSession.clearDisplayPreview() }
                                }
                            }
                            switch sampleSession.displayStatus {
                            case .idle: EmptyView()
                            case .running: ProgressView("正在生成整图预览…")
                            case .loaded:
                                if let bitmap = sampleSession.displayBitmap {
                                    LabeledContent("显示目标", value: "sRGB D65 / W3C extended")
                                    LabeledContent("预览像素", value: "\(bitmap.width) × \(bitmap.height)")
                                    if let cgImage = bitmap.cgImage() {
                                        Image(decorative: cgImage, scale: 1, orientation: .up)
                                            .resizable()
                                            .interpolation(.none)
                                            .scaledToFit()
                                            .frame(maxHeight: 320)
                                            .accessibilityLabel("CPU Double sRGB 屏幕预览")
                                    }
                                }
                            case .failed(let message):
                                Text("预览失败：\(message)").foregroundStyle(.red)
                            case .closed: EmptyView()
                            }
                            HStack {
                                TextField("X 坐标", text: $sampleXDraft)
                                    .accessibilityLabel("图像 X 坐标")
                                    .accessibilityHint("输入整数像素横坐标")
                                TextField("Y 坐标", text: $sampleYDraft)
                                    .accessibilityLabel("图像 Y 坐标")
                                    .accessibilityHint("输入整数像素纵坐标")
                                Button("取样") { samplePixel() }
                                    .accessibilityHint("按当前项目输入解释取样像素")
                                    .disabled(!confirmedSource)
                            }
                        }
                    case .failed(let message): Text("图像解码失败：\(message)").foregroundStyle(.red)
                    case .closed: EmptyView()
                    }
                    if let sampleError { Text(sampleError).foregroundStyle(.red) }
                    if let sample = sampleSession.sampleRecord,
                       sample.revision == document.revision {
                        Text("坐标 (\(sample.x), \(sample.y))，项目修订 \(sample.revision)")
                        Text("源 RGB：\(rgbText(sample.pixel.source.rgb))；alpha：\(sample.pixel.source.alpha)")
                        Text("进入计划：\(rgbText(sample.pixel.inputToPlan))")
                        Text("计划输出：\(rgbText(sample.pixel.planOutput))")
                    }
                }
                Section("用户 LUT 数值检查") {
                    Button("导入 LUT") { showLUTImporter = true }
                        .disabled(!document.storedUserLUTPaths.isEmpty)
                    Text("用户所选 LUT 会作为原始文件加入项目。生成后置阶段在输出编码及范围换算之后应用，使用 LUT 自身输入域；每个项目暂支持一份用户 LUT。")
                        .foregroundStyle(.secondary)
                    if let storedPath = document.storedUserLUTPaths.first {
                        LabeledContent("项目资源", value: String(storedPath.dropFirst("Resources/".count)))
                        if let stage = document.manifest.userLUTPostStage {
                            Picker("生成后置插值", selection: Binding(
                                get: { stage.interpolation },
                                set: { configureUserLUTPostStage(.init(interpolation: $0, outside: stage.outside)) }
                            )) {
                                Text("线性 / 三线性").tag(LUTInterpolation.trilinear)
                                Text("四面体").tag(LUTInterpolation.tetrahedral)
                                Text("旧三次").tag(LUTInterpolation.tricubicLegacyV1)
                            }
                            Picker("生成后置域外策略", selection: Binding(
                                get: { stage.outside },
                                set: { configureUserLUTPostStage(.init(interpolation: stage.interpolation, outside: $0)) }
                            )) {
                                Text("拒绝域外").tag(LUTOutsidePolicy.reject)
                                Text("裁剪到 LUT 输入域").tag(LUTOutsidePolicy.clampToDomain)
                                if userLUTSession.imported?.lut.dimension == .one,
                                   stage.interpolation == .tricubicLegacyV1 {
                                    Text("旧 1D 三次端点延拓").tag(LUTOutsidePolicy.legacyExtensionV1)
                                }
                            }
                        } else {
                            Text("当前兼容设置只生成单位域 1D 线性后置阶段；其他布局需显式配置。")
                                .foregroundStyle(.secondary)
                            Button("配置生成后置阶段") {
                                configureUserLUTPostStage(.init(interpolation: lutInterpolation, outside: .reject))
                            }
                        }
                        Button("导出项目中的原始 LUT") {
                            do {
                                storedLUTExportDocument = try document.makeStoredUserLUTExport()
                                showStoredLUTExporter = true
                            } catch {
                                lutSampleError = "无法导出项目 LUT：\(error)"
                            }
                        }
                    }
                    switch userLUTSession.loadStatus {
                    case .idle: EmptyView()
                    case .running: ProgressView("正在读取 LUT…")
                    case .loaded:
                        if let imported = userLUTSession.imported {
                            LabeledContent("文件", value: imported.url.lastPathComponent)
                            LabeledContent("格式与尺寸", value:
                                "\(imported.format.rawValue)，\(imported.lut.dimension.rawValue)D，\(imported.lut.size)")
                            LabeledContent("输入域", value:
                                "\(rgbText(imported.lut.domain.min)) → \(rgbText(imported.lut.domain.max))")
                            if let analysis = imported.analysis {
                                LabeledContent("分析文件", value: analysis.sourceFormat)
                                if let name = analysis.transferMetadata.inputTransferFunction {
                                    LabeledContent("原文件标注曲线", value: name)
                                }
                                Text("文件元数据仅作来源说明，不自动认定为内置转换公式。")
                                    .foregroundStyle(.secondary)
                                if analysis.colourLUT != nil {
                                    Text("下方直接取样只读取 1D transfer；灰轴检查只读取独立 3D colour 分节。")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button("分析曲线与反求条件") { inspectLUTStructure() }
                            if let report = userLUTSession.analysisReport {
                                if let transfer = report.transfer {
                                    LabeledContent("R 通道", value: channelAnalysisText(transfer.red))
                                    LabeledContent("G 通道", value: channelAnalysisText(transfer.green))
                                    LabeledContent("B 通道", value: channelAnalysisText(transfer.blue))
                                    Text(transfer.isInvertibleBySingleValue
                                         ? "三个 1D 通道均严格单调，可分别单值反求。"
                                         : "至少一个 1D 通道有平段或反转，不能将整条曲线作为单值反函数。")
                                    if transfer.isInvertibleBySingleValue {
                                        HStack {
                                            TextField("输出 R", text: $inverseRedDraft)
                                            TextField("输出 G", text: $inverseGreenDraft)
                                            TextField("输出 B", text: $inverseBlueDraft)
                                            Button("线性反求 1D 输入") { inverseImportedTransfer() }
                                        }
                                        if let output = userLUTSession.inverseOutput,
                                           let input = userLUTSession.inverseInput {
                                            Text("1D 目标：\(rgbText(output))")
                                            Text("1D 输入：\(rgbText(input))")
                                        }
                                        if let inverseError {
                                            Text("反求失败：\(inverseError)").foregroundStyle(.red)
                                        }
                                    }
                                }
                                if let shaper = report.shaper {
                                    Text("组合 CUBE 的前置 1D 曲线：\(shaper.isInvertibleBySingleValue ? "三个通道严格单调" : "存在平段或反转")")
                                }
                                if report.hasColourLUT {
                                    Text("三维颜色 LUT 未获全局可逆性证明；任意 3D 反求暂不可用。")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let structureError { Text("分析失败：\(structureError)").foregroundStyle(.red) }
                            Picker("插值", selection: Binding(
                                get: {
                                    if imported.lut.dimension == .one, imported.analysis?.colourLUT == nil,
                                       lutInterpolation == .trilinear { return .tetrahedral }
                                    return lutInterpolation
                                },
                                set: { lutInterpolation = $0 }
                            )) {
                                if imported.lut.dimension == .three || imported.analysis?.colourLUT != nil {
                                    Text("四面体").tag(LUTInterpolation.tetrahedral)
                                    Text("三线性").tag(LUTInterpolation.trilinear)
                                } else {
                                    Text("线性").tag(LUTInterpolation.tetrahedral)
                                }
                                Text("三次").tag(LUTInterpolation.tricubicLegacyV1)
                            }
                            if lutInterpolation == .tricubicLegacyV1 {
                                Text("三次取样保留过冲；1D / shaper 至少 3 点，3D 每轴至少 4 点。端点斜率可能按旧规则修正。")
                                    .foregroundStyle(.secondary)
                            }
                            if imported.lut.dimension == .three || imported.analysis?.colourLUT != nil {
                                Button("检查灰轴") { inspectGrayAxis() }
                                if let grayAxisReport {
                                    Text("归一化灰轴：\(grayAxisReport.samples.count) 个样本，\(grayAxisReport.midpointProbeCount) 个中点；最大通道重建残差 \(grayAxisReport.maximumMidpointResidual)")
                                    Text("残差仅描述输入域对角线，不代表完整三维重建。")
                                        .foregroundStyle(.secondary)
                                }
                                if let grayAxisError { Text(grayAxisError).foregroundStyle(.red) }
                            }
                            if imported.analysis?.colourLUT != nil {
                                Picker("取样分节", selection: $lutSampleSection) {
                                    Text("1D transfer").tag(UserLUTSampleSection.primary)
                                    Text("3D colour").tag(UserLUTSampleSection.colour)
                                }
                            }
                            HStack {
                                TextField("R", text: $lutRedDraft)
                                    .accessibilityLabel("用户 LUT 输入红色通道")
                                TextField("G", text: $lutGreenDraft)
                                    .accessibilityLabel("用户 LUT 输入绿色通道")
                                TextField("B", text: $lutBlueDraft)
                                    .accessibilityLabel("用户 LUT 输入蓝色通道")
                                Button("取样") { sampleImportedLUT() }
                                    .accessibilityHint("按所选插值方式取样用户 LUT")
                            }
                            if let input = userLUTSession.sampleInput,
                               let output = userLUTSession.sampleOutput {
                                Text("输入：\(rgbText(input))")
                                    Text("\(userLUTSession.sampleSection == .colour ? "3D colour" : "1D transfer / LUT") 输出：\(rgbText(output))")
                                if !userLUTSession.cubicEndpointSlopes.isEmpty {
                                    ForEach(0..<userLUTSession.cubicEndpointSlopes.count, id: \.self) { channel in
                                        let slopes = userLUTSession.cubicEndpointSlopes[channel]
                                        if slopes.lower.modified || slopes.upper.modified {
                                            Text("本次三次取样 \(["R", "G", "B"][channel]) 端点斜率（样本索引域）：\(slopes.lower.raw) → \(slopes.lower.applied)，\(slopes.upper.raw) → \(slopes.upper.applied)。原始样本未修改。")
                                        }
                                    }
                                }
                            }
                        }
                    case .failed(let message): Text("LUT 读取失败：\(message)").foregroundStyle(.red)
                    case .closed: EmptyView()
                    }
                    if let lutSampleError { Text(lutSampleError).foregroundStyle(.red) }
                }
            }
            .navigationTitle("LUTCalc")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if exportSession.exportStatus == .running {
                        Button("取消生成") { exportSession.cancel() }
                            .accessibilityIdentifier("cancelLUTButton")
                            .accessibilityLabel("取消生成")
                    } else {
                        Button("生成 \(exportFormat.rawValue.uppercased())") { startExport() }
                            .accessibilityLabel("生成 \(exportFormat.rawValue.uppercased()) LUT")
                            .accessibilityHint("按当前项目设置在后台生成当前格式文件")
                            .keyboardShortcut("g", modifiers: [.command])
                            .accessibilityIdentifier("toolbarGenerateLUTButton")
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 360)
        .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                confirmedSource = false
                sampleXDraft = "0"
                sampleYDraft = "0"
                sampleError = nil
                sampleSession.startLoading(url)
            case .failure(let error):
                if !Self.isUserCancelled(error) {
                    sampleError = "无法选择图像：\(error)"
                }
            }
        }
        .sheet(item: $gammaEditor) { context in
            ParameterizedGammaEditorView(document: $document, context: context)
        }
        .fileImporter(isPresented: $showLUTImporter, allowedContentTypes: [
            UTType(filenameExtension: "cube") ?? .data,
            UTType(filenameExtension: "spi1d") ?? .data,
            UTType(filenameExtension: "spi3d") ?? .data,
            UTType(filenameExtension: "3dl") ?? .data,
            UTType(filenameExtension: "ilut") ?? .data,
            UTType(filenameExtension: "olut") ?? .data,
            UTType(filenameExtension: "lut") ?? .data,
            UTType(filenameExtension: "vlt") ?? .data,
            UTType(filenameExtension: "lacube") ?? .data,
            UTType(filenameExtension: "labin") ?? .data,
        ]) { result in
            switch result {
            case .success(let url):
                lutSampleError = nil
                grayAxisReport = nil
                grayAxisError = nil
                structureError = nil
                inverseError = nil
                lutSampleSection = .primary
                userLUTSession.startLoading(url)
            case .failure(let error):
                if !Self.isUserCancelled(error) {
                    lutSampleError = "无法选择 LUT：\(error)"
                }
            }
        }
        .fileExporter(isPresented: $showStoredLUTExporter,
                      document: storedLUTExportDocument,
                      contentType: .data,
                      defaultFilename: storedLUTExportDocument.suggestedFilename) { result in
            if case .failure(let error) = result {
                if !Self.isUserCancelled(error) {
                    lutSampleError = "无法保存 LUT：\(error)"
                }
            }
        }
        .fileExporter(isPresented: $showGeneratedLUTExporter,
                      document: generatedLUTExportDocument,
                      contentType: generatedLUTExportDocument.contentType,
                      defaultFilename: generatedLUTExportDocument.suggestedFilename) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let readback = try Data(contentsOf: url, options: [.mappedIfSafe])
                    guard readback == generatedLUTExportDocument.bytes else {
                        generatedLUTSaveResult = "文件已提交，但回读内容与生成结果不一致。"
                        return
                    }
                    generatedLUTSaveResult = "文件已保存并回读核对：\(url.lastPathComponent)"
                } catch {
                    generatedLUTSaveResult = "文件已提交，但无法回读核对：\(error)"
                }
            case .failure(let error):
                if !Self.isUserCancelled(error) {
                    inputError = "无法保存生成的 LUT：\(error)"
                    generatedLUTSaveResult = "文件保存失败。"
                }
            }
        }
        .onChange(of: document.manifest.settings.exposureStops.bitPattern) { _, _ in
            exposureDraft = String(document.manifest.settings.exposureStops)
        }
        .onChange(of: document.revision) { _, _ in
            confirmedSource = false
            sampleSession.clearSample()
            sampleSession.clearDisplayPreview()
        }
        .onChange(of: document.manifest.id) { _, _ in
            confirmedSource = false
            sampleSession.resetForDocumentSwitch()
            sampleError = nil
            sampleXDraft = "0"
            sampleYDraft = "0"
            userLUTSession.clear()
            lutSampleError = nil
            grayAxisReport = nil
            grayAxisError = nil
            structureError = nil
            inverseError = nil
            lutSampleSection = .primary
            showStoredUserLUT()
        }
        .onChange(of: lutInterpolation) { _, _ in
            grayAxisReport = nil
            grayAxisError = nil
        }
        .onChange(of: lutSampleSection) { _, _ in
            lutSampleError = nil
        }
        .onChange(of: userLUTSession.loadStatus) { _, status in
            grayAxisReport = nil
            grayAxisError = nil
            structureError = nil
            inverseError = nil
            guard status == .loaded, document.storedUserLUTPaths.isEmpty,
                  let imported = userLUTSession.imported else { return }
            do {
                var updated = document
                let path = try updated.storeImportedUserLUT(imported)
                let stored = try updated.inspectStoredUserLUT(at: path)
                exportSession.close()
                exportSession = ProjectExportSession()
                document = updated
                userLUTSession.showStored(stored)
                lutSampleError = nil
            } catch {
                userLUTSession.clear()
                lutSampleError = "无法将 LUT 加入项目：\(error)"
            }
        }
        .onAppear {
            exportSession.reopen()
            showStoredUserLUT()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                exportSession.suspendForBackground()
            case .active:
                exportSession.reopen()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
#if os(iOS)
        // DocumentGroup can rebuild the document view while the scene is being
        // suspended. Observe the UIKit lifecycle as a second boundary so an
        // in-flight export is cancelled at the earlier will-resign-active edge,
        // even when SwiftUI does not deliver the `scenePhase` change to this
        // view instance.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.willResignActiveNotification)) { _ in
            exportSession.suspendForBackground()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification)) { _ in
            exportSession.suspendForBackground()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in
            exportSession.reopen()
        }
#endif
        .onDisappear {
            // Going to the Home screen may temporarily remove a DocumentGroup
            // view. Keep the session alive for the background cancellation
            // boundary; close only when the document is actually dismissed.
#if os(iOS)
            // DocumentGroup may remove this view before delivering a scene
            // notification. Treat disappearance as the conservative iOS
            // background boundary so an in-flight export cannot finish while
            // the app is suspended.
            exportSession.suspendForBackground()
#else
            exportSession.close()
#endif
            sampleSession.close()
            userLUTSession.close()
        }
    }

    private static func isUserCancelled(_ error: Error) -> Bool {
        SystemFileDialogError.isUserCancellation(error)
    }

    private var currentOutputMode: OutputMode {
        switch (document.manifest.settings.outputTransfer, document.manifest.settings.outputSpace) {
        case (.linearScene, .acesAP0): .linearAP0
        case (.djiDLog2, .djiDGamut2): .dlog2DGamut2
        default: .custom
        }
    }

    private var currentPresetID: String {
        Self.catalogPresets.first(where: { $0.settings == document.manifest.settings })?.id ?? "custom"
    }

    private func setPreset(_ id: String) {
        guard id != "custom", let preset = Self.catalogPresets.first(where: { $0.id == id }) else { return }
        do {
            var updated = document
            try updated.applyPreset(preset)
            document = updated
            exposureDraft = String(preset.settings.exposureStops)
            inputError = nil
        } catch {
            inputError = "无法应用预设：\(error)"
        }
    }

    private func setInputRange(_ range: SignalNormalization) {
        let old = document.manifest.settings
        apply(settings: old.withInputRange(range))
    }

    private func setInputSelection(transfer: TransferID, space: ColorSpaceID) {
        apply(settings: document.manifest.settings.withInput(transfer: transfer, space: space))
    }

    private func setOutputSelection(transfer: TransferID, space: ColorSpaceID) {
        apply(settings: document.manifest.settings.withOutput(transfer: transfer, space: space))
    }

    private func setOutputRange(_ range: SignalNormalization) {
        apply(settings: document.manifest.settings.withOutputRange(range))
    }

    private func setRangeBitDepth(_ depth: Int) {
        guard [8, 10, 12].contains(depth) else { return }
        apply(settings: document.manifest.settings.withRangeBitDepth(depth))
    }

    private func setAdaptation(_ method: ChromaticAdaptation) {
        apply(settings: document.manifest.settings.withAdaptation(method))
    }

    private func setOutputMode(_ mode: OutputMode) {
        guard mode != .custom else { return }
        let old = document.manifest.settings
        apply(settings: old.withOutput(
            transfer: mode == .linearAP0 ? .linearScene : .djiDLog2,
            space: mode == .linearAP0 ? .acesAP0 : .djiDGamut2))
    }

    private func setCubeSize(_ size: Int) {
        guard [17, 33, 65].contains(size) else { return }
        apply(cubeSize: size)
    }

    private func commitExposure() {
        guard let value = Double(exposureDraft), value.isFinite else {
            inputError = "请输入有限的曝光档数。"
            return
        }
        if value == document.manifest.settings.exposureStops {
            inputError = nil
            return
        }
        let old = document.manifest.settings
        apply(settings: old.withExposureStops(value))
    }

    private func apply(settings: TransformSettings? = nil, cubeSize: Int? = nil) {
        let old = document.manifest
        do {
            var updated = document
            try updated.apply(ProjectManifest(
                id: old.id, settings: settings ?? old.settings,
                cubeSize: cubeSize ?? old.cubeSize, domain: old.domain,
                assetHashes: old.assetHashes, assetRoles: old.assetRoles,
                userLUTPostStage: old.userLUTPostStage,
                userLUTInputInverse: old.userLUTInputInverse))
            document = updated
            inputError = nil
        } catch { inputError = "项目设置无效：\(error)" }
    }

    private func configureUserLUTPostStage(_ settings: UserLUTPostStageSettings) {
        do {
            var updated = document
            try updated.applyUserLUTPostStage(settings)
            document = updated
            lutSampleError = nil
        } catch { lutSampleError = "生成后置阶段配置无效：\(error)" }
    }

    private func changeHistory(undo: Bool) {
        var updated = document
        let changed = undo ? updated.undo() : updated.redo()
        guard changed else { return }
        document = updated
        exposureDraft = String(updated.manifest.settings.exposureStops)
        inputError = nil
    }

    private func startExport() {
        commitExposure()
        guard inputError == nil else { return }
        // DocumentGroup may deliver the first button action immediately around a
        // view lifecycle transition. Reopen here as well as in onAppear so the
        // request cannot be silently rejected by a prior onDisappear cleanup.
        exportSession.reopen()
        if !exportSession.start(document: document, format: exportFormat) {
            inputError = "导出请求未启动；当前状态：\(statusText)"
        }
    }

    private func samplePixel() {
        guard let x = Int(sampleXDraft), let y = Int(sampleYDraft) else {
            sampleError = "请输入整数像素坐标。"
            return
        }
        do {
            _ = try sampleSession.sample(document: document, x: x, y: y,
                                         confirmedSource: confirmedSource)
            sampleError = nil
        } catch { sampleError = "取样失败：\(error)" }
    }

    private func sampleImportedLUT() {
        guard let red = Double(lutRedDraft), let green = Double(lutGreenDraft),
              let blue = Double(lutBlueDraft), red.isFinite, green.isFinite, blue.isFinite else {
            lutSampleError = "请输入有限的 RGB 数值。"
            return
        }
        do {
            _ = try userLUTSession.sample(RGB64(red, green, blue),
                                          interpolation: lutInterpolation, outside: .reject,
                                          section: lutSampleSection)
            lutSampleError = nil
        } catch { lutSampleError = "LUT 取样失败：\(error)" }
    }

    private func inspectGrayAxis() {
        guard let imported = userLUTSession.imported else {
            grayAxisError = "尚未载入用户 LUT。"
            return
        }
        do {
            grayAxisReport = try GrayAxisAnalyzer.extract(imported.analysis?.colourLUT ?? imported.lut,
                                                           interpolation: lutInterpolation)
            grayAxisError = nil
        } catch {
            grayAxisReport = nil
            grayAxisError = "灰轴检查失败：\(error)"
        }
    }

    private func inspectLUTStructure() {
        do {
            _ = try userLUTSession.inspectStructure()
            structureError = nil
        } catch {
            structureError = String(describing: error)
        }
    }

    private func inverseImportedTransfer() {
        guard let red = Double(inverseRedDraft), let green = Double(inverseGreenDraft),
              let blue = Double(inverseBlueDraft), red.isFinite, green.isFinite, blue.isFinite else {
            inverseError = "请输入有限的 RGB 目标值。"
            return
        }
        do {
            _ = try userLUTSession.inverseTransfer(RGB64(red, green, blue))
            inverseError = nil
        } catch {
            inverseError = String(describing: error)
        }
    }

    private func channelAnalysisText(_ analysis: MonotonicCurve1DAnalysis) -> String {
        let direction: String
        switch analysis.direction {
        case .increasing: direction = "递增"
        case .decreasing: direction = "递减"
        case .constant: direction = "常量"
        case .nonMonotonic: direction = "反单调"
        }
        return "\(direction)；平段 \(analysis.flatSegmentIndices.count)；反转 \(analysis.reversalIndices.count)；\(analysis.isInvertibleBySingleValue ? "可单值反求" : "不可单值反求")"
    }

    private func showStoredUserLUT() {
        guard let path = document.storedUserLUTPaths.first else { return }
        do {
            userLUTSession.showStored(try document.inspectStoredUserLUT(at: path))
            lutSampleError = nil
        } catch {
            userLUTSession.clear()
            lutSampleError = "项目内 LUT 无法检查：\(error)"
        }
    }

    private func prepareGeneratedLUTExport(_ record: ExportRecord) {
        do {
            let filename = "LUTCalc-\(document.manifest.id.uuidString).\(record.url.pathExtension)"
            generatedLUTExportDocument = try GeneratedLUTExportDocument(
                sourceURL: record.url, suggestedFilename: filename)
            inputError = nil
            generatedLUTSaveResult = nil
            showGeneratedLUTExporter = true
        } catch {
            inputError = "无法准备生成的 LUT：\(error)"
        }
    }

    private func rgbText(_ rgb: RGB64) -> String {
        "R \(rgb.r)，G \(rgb.g)，B \(rgb.b)"
    }

    private func algorithmLabel(_ aliases: [String], fallback: String) -> String {
        aliases.first ?? fallback
    }

    private var statusText: String {
        switch exportSession.exportStatus {
        case .idle: "请选择参数并生成。"
        case .running: "正在计算和保存…"
        case .succeeded: "LUT 已生成，可分享或保存。"
        case .cancelled: "生成已取消。"
        case .failed(let message): "生成失败：\(message)"
        }
    }

    private var statusIsError: Bool {
        if case .failed = exportSession.exportStatus { return true }
        return false
    }
}

private struct DocumentNavigationContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if os(iOS)
        content
        #else
        NavigationStack { content }
        #endif
    }
}
