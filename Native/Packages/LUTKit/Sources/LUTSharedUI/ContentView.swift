import SwiftUI
import LUTCore

public struct ContentView: View {
    @State private var session = EditorSession()
    @State private var exportTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("输入") {
                    LabeledContent("曲线", value: session.currentSettings?.inputTransfer.rawValue ?? "DJI D-Log2")
                    LabeledContent("色域", value: session.currentSettings?.inputSpace.rawValue ?? "DJI D-Gamut2")
                    Picker("输入范围", selection: Binding(
                        get: { session.inputRange },
                        set: { session.setInputRange($0) }
                    )) {
                        Text("Data").tag(SignalNormalization.data)
                        Text("Legal / Video").tag(SignalNormalization.video)
                    }
                }
                Section("变换") {
                    HStack {
                        TextField("曝光档数", text: Binding(
                            get: { session.exposureDraft },
                            set: { session.exposureDraft = $0 }
                        ))
                        .onSubmit { _ = session.commitExposure() }
                        Button("应用曝光") { _ = session.commitExposure() }
                    }
                    if let inputError = session.inputError {
                        Text(inputError).foregroundStyle(.red)
                    }
                }
                Section("输出") {
                    Picker("目标", selection: Binding(
                        get: { session.outputMode },
                        set: { session.setOutputMode($0) }
                    )) {
                        Text("线性 ACES AP0").tag(OutputMode.linearAP0)
                        Text("DJI D-Log2 / D-Gamut2").tag(OutputMode.dlog2DGamut2)
                        Text("项目当前目标").tag(OutputMode.custom)
                    }
                    if let settings = session.currentSettings {
                        LabeledContent("当前输出曲线", value: settings.outputTransfer.rawValue)
                        LabeledContent("当前输出色域", value: settings.outputSpace.rawValue)
                    }
                    Picker("3D 尺寸", selection: Binding(
                        get: { session.cubeSize },
                        set: { session.setCubeSize($0) }
                    )) {
                        ForEach(Array(Set([17, 33, 65, session.cubeSize])).sorted(), id: \.self) { size in
                            Text("\(size)³").tag(size)
                        }
                    }
                    if let projectURL = session.projectURL {
                        LabeledContent("项目", value: projectURL.lastPathComponent)
                        if session.isProjectDirty { Text("项目有未保存修改") }
                    }
                    HStack {
                        Button("生成 CUBE") {
                            exportTask = Task { await session.export() }
                        }
                        .disabled(session.exportStatus == .running)
                        if session.exportStatus == .running {
                            Button("取消") { exportTask?.cancel() }
                        }
                    }
                    Text(statusText)
                        .foregroundStyle(statusIsError ? .red : .secondary)
                    if let record = session.lastExport {
                        ShareLink(item: record.url) {
                            Label("分享或保存 CUBE", systemImage: "square.and.arrow.up")
                        }
                        Text("导出请求版本 \(record.revision)，\(record.writtenNodes) 个节点")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("LUTCalc")
        }
        .frame(minWidth: 320, minHeight: 360)
    }

    private var statusText: String {
        switch session.exportStatus {
        case .idle: "请选择参数并生成。"
        case .running: "正在计算和保存…"
        case .succeeded: "CUBE 已生成，可分享或保存。"
        case .cancelled: "生成已取消。"
        case .failed(let message): "生成失败：\(message)"
        }
    }

    private var statusIsError: Bool {
        if case .failed = session.exportStatus { return true }
        return false
    }
}
