import Foundation
import SwiftUI
import LUTCore

public enum ParameterizedGammaSlot: String, Equatable, Sendable {
    case input
    case output
}

public enum ParameterizedGammaDraftError: Error, Equatable, Sendable {
    case invalidNumber
    case staleRevision
}

public struct ParameterizedGammaDraft: Equatable, Sendable {
    public var exponent: String
    public var linearSlope: String
    public var offset: String
    public var linearCut: String
    public var encodedCut: String

    public init(exponent: String = "", linearSlope: String = "", offset: String = "",
                linearCut: String = "", encodedCut: String = "") {
        self.exponent = exponent
        self.linearSlope = linearSlope
        self.offset = offset
        self.linearCut = linearCut
        self.encodedCut = encodedCut
    }

    public init(existing: ParameterizedGammaSettings?) {
        self.init(exponent: existing.map { String($0.exponent) } ?? "",
                  linearSlope: existing.map { String($0.linearSlope) } ?? "",
                  offset: existing.map { String($0.offset) } ?? "",
                  linearCut: existing.map { String($0.linearCut) } ?? "",
                  encodedCut: existing?.encodedCut.map { String($0) } ?? "")
    }

    public func makeSettings() throws -> ParameterizedGammaSettings {
        func number(_ text: String) throws -> Double {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else {
                throw ParameterizedGammaDraftError.invalidNumber
            }
            return value
        }
        let optionalCut = encodedCut.trimmingCharacters(in: .whitespacesAndNewlines)
        return try ParameterizedGammaSettings(
            exponent: number(exponent), linearSlope: number(linearSlope),
            offset: number(offset), linearCut: number(linearCut),
            encodedCut: optionalCut.isEmpty ? nil : number(optionalCut))
    }
}

struct ParameterizedGammaEditorContext: Identifiable {
    let id = UUID()
    let slot: ParameterizedGammaSlot
    let revision: UInt64
}

struct ParameterizedGammaEditorView: View {
    @Binding var document: LUTProjectDocument
    let context: ParameterizedGammaEditorContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ParameterizedGammaDraft
    @State private var errorText: String?

    init(document: Binding<LUTProjectDocument>, context: ParameterizedGammaEditorContext) {
        _document = document
        self.context = context
        let settings = document.wrappedValue.manifest.settings
        _draft = State(initialValue: ParameterizedGammaDraft(
            existing: context.slot == .input ? settings.inputGamma : settings.outputGamma))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("分段幂函数参数") {
                    TextField("指数 exponent", text: $draft.exponent)
                    TextField("线性段斜率 linearSlope", text: $draft.linearSlope)
                    TextField("偏置 offset", text: $draft.offset)
                    TextField("线性切点 linearCut", text: $draft.linearCut)
                    TextField("编码切点 encodedCut（可留空）", text: $draft.encodedCut)
                    Text("留空的 encodedCut 按 linearSlope × linearCut 计算。所有字段以 Double 保存。")
                        .foregroundStyle(.secondary)
                }
                if let errorText { Text(errorText).foregroundStyle(.red) }
            }
            .navigationTitle(context.slot == .input ? "输入自定义 Gamma" : "输出自定义 Gamma")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") { commit() }
                }
            }
        }
        .frame(minWidth: 340, minHeight: 360)
    }

    private func commit() {
        do {
            var updated = document
            try updated.applyParameterizedGamma(draft, slot: context.slot,
                                                expectedRevision: context.revision)
            document = updated
            errorText = nil
            dismiss()
        } catch {
            errorText = "参数无效或项目已变化：\(error)"
        }
    }
}
