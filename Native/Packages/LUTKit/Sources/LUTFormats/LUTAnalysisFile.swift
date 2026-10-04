import Foundation
import LUTCore

public enum LUTAnalysisFailureCategory: String, Equatable, Sendable {
    case invalidEncoding
    case malformedHeader
    case invalidDimension
    case resourceLimit
    case truncated
    case invalidMetadata
    case invalidNumber
    case nonFiniteValue
    case lossyRepresentation
    case invalidLength
    case unsupported
}

public struct LUTAnalysisFailure: Error, Equatable, Sendable {
    public let category: LUTAnalysisFailureCategory
    public let offset: Int

    public init(_ category: LUTAnalysisFailureCategory, offset: Int = 0) {
        self.category = category
        self.offset = offset
    }
}

public struct LUTAnalysisSectionMetadata: Equatable, Sendable {
    public var inputTransferFunction: String?
    public var systemColourspace: String?
    public var inputColourspace: String?
    public var inputRange: String?
    public var inputMinimum: Double?
    public var inputMaximum: Double?
    public var interpolation: String?
    public var baseISO: Int?
    public var inputMatrix: Matrix3x3?
    public var rawText: String?

    public init(inputTransferFunction: String? = nil, systemColourspace: String? = nil,
                inputColourspace: String? = nil, inputRange: String? = nil,
                inputMinimum: Double? = nil, inputMaximum: Double? = nil,
                interpolation: String? = nil, baseISO: Int? = nil,
                inputMatrix: Matrix3x3? = nil, rawText: String? = nil) {
        self.inputTransferFunction = inputTransferFunction
        self.systemColourspace = systemColourspace
        self.inputColourspace = inputColourspace
        self.inputRange = inputRange
        self.inputMinimum = inputMinimum
        self.inputMaximum = inputMaximum
        self.interpolation = interpolation
        self.baseISO = baseISO
        self.inputMatrix = inputMatrix
        self.rawText = rawText
    }
}

public enum LUTAnalysisInputRange: Equatable, Sendable {
    case extended
    case data
    case unspecified
    case unknown(String)
}

public enum LUTAnalysisInterpolation: Equatable, Sendable {
    case tricubic
    case tetrahedral
    case trilinear
    case unspecified
    case unknown(String)
}

public enum LUTAnalysisMetadataError: Error, Equatable, Sendable {
    case incompleteBounds
    case nonFiniteBounds
    case invalidBounds
}

public struct LUTAnalysisMetadataSemantics: Equatable, Sendable {
    public let inputRange: LUTAnalysisInputRange
    public let inputBounds: ClosedRange<Double>
    public let interpolation: LUTAnalysisInterpolation
    public let baseISO: Int?

    public init(inputRange: LUTAnalysisInputRange,
                inputBounds: ClosedRange<Double>,
                interpolation: LUTAnalysisInterpolation,
                baseISO: Int?) {
        self.inputRange = inputRange
        self.inputBounds = inputBounds
        self.interpolation = interpolation
        self.baseISO = baseISO
    }
}

/// Describes how an analysis file represents numeric samples.  This is a
/// format contract, not a claim that legacy quantized values are lossless.
public struct LUTAnalysisQuantizationSemantics: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case textualDouble
        case legacyLABin
        case unknown
    }

    public enum ByteOrder: String, Equatable, Sendable {
        case littleEndian
    }

    public enum Rounding: String, Equatable, Sendable {
        case floorPlusHalf
    }

    public let kind: Kind
    public let sampleScale: Double?
    public let matrixScale: Double?
    public let lossySentinel: Int32?
    public let byteOrder: ByteOrder?
    public let rounding: Rounding?

    public init(kind: Kind, sampleScale: Double? = nil, matrixScale: Double? = nil,
                lossySentinel: Int32? = nil, byteOrder: ByteOrder? = nil,
                rounding: Rounding? = nil) {
        self.kind = kind
        self.sampleScale = sampleScale
        self.matrixScale = matrixScale
        self.lossySentinel = lossySentinel
        self.byteOrder = byteOrder
        self.rounding = rounding
    }

    public static let textualDouble = LUTAnalysisQuantizationSemantics(kind: .textualDouble)

    public static let legacyLABin = LUTAnalysisQuantizationSemantics(
        kind: .legacyLABin,
        sampleScale: 1_073_741_824.0,
        matrixScale: 107_374_182.4,
        lossySentinel: 2_136_746_230,
        byteOrder: .littleEndian,
        rounding: .floorPlusHalf)

    public static let unknown = LUTAnalysisQuantizationSemantics(kind: .unknown)
}

public extension LUTAnalysisSectionMetadata {
    /// Converts the legacy textual fields into explicit semantics without
    /// changing the original metadata or guessing unknown producer values.
    func semantics() throws -> LUTAnalysisMetadataSemantics {
        let range: LUTAnalysisInputRange
        if let raw = inputRange?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            switch raw.lowercased() {
            case "109": range = .extended
            case "100": range = .data
            default: range = .unknown(raw)
            }
        } else {
            range = .unspecified
        }

        let bounds: ClosedRange<Double>
        if inputMinimum?.isFinite == false || inputMaximum?.isFinite == false {
            throw LUTAnalysisMetadataError.nonFiniteBounds
        }
        switch (inputMinimum, inputMaximum) {
        case (nil, nil):
            bounds = 0...1
        case let (minimum?, maximum?):
            guard minimum < maximum else {
                throw LUTAnalysisMetadataError.invalidBounds
            }
            bounds = minimum...maximum
        default:
            throw LUTAnalysisMetadataError.incompleteBounds
        }

        let method: LUTAnalysisInterpolation
        if let raw = interpolation?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            switch raw.lowercased() {
            case "tricubic": method = .tricubic
            case "tetrahedral": method = .tetrahedral
            case "trilinear": method = .trilinear
            default: method = .unknown(raw)
            }
        } else {
            method = .unspecified
        }
        return LUTAnalysisMetadataSemantics(inputRange: range,
                                             inputBounds: bounds,
                                             interpolation: method,
                                             baseISO: baseISO)
    }
}

public struct LUTAnalysisFile: Equatable, Sendable {
    public let title: String?
    public let transferLUT: CubeLUT
    public let colourLUT: CubeLUT?
    public let transferMetadata: LUTAnalysisSectionMetadata
    public let colourMetadata: LUTAnalysisSectionMetadata?
    public let sourceFormat: String

    public init(title: String?, transferLUT: CubeLUT, colourLUT: CubeLUT?,
                transferMetadata: LUTAnalysisSectionMetadata,
                colourMetadata: LUTAnalysisSectionMetadata?, sourceFormat: String) {
        self.title = title
        self.transferLUT = transferLUT
        self.colourLUT = colourLUT
        self.transferMetadata = transferMetadata
        self.colourMetadata = colourMetadata
        self.sourceFormat = sourceFormat
    }

    public var quantizationSemantics: LUTAnalysisQuantizationSemantics {
        switch sourceFormat.lowercased() {
        case "lacube": return .textualDouble
        case "labin": return .legacyLABin
        default: return .unknown
        }
    }
}

private enum LUTAnalysisParsing {
    static let maxFileBytes = CubeParser.maxFileBytes
    static let scale = LUTAnalysisQuantizationSemantics.legacyLABin.sampleScale!
    static let matrixScale = LUTAnalysisQuantizationSemantics.legacyLABin.matrixScale!
    static let sampleSentinel = LUTAnalysisQuantizationSemantics.legacyLABin.lossySentinel!

    static func finiteNumber(_ token: Substring) throws -> Double {
        guard !token.isEmpty, let value = Double(token) else {
            throw LUTAnalysisFailure(.invalidNumber)
        }
        guard value.isFinite else { throw LUTAnalysisFailure(.nonFiniteValue) }
        return value
    }

    static func parseCube(_ data: Data) throws -> CubeLUT {
        do {
            return try CubeParser.parse(data)
        } catch let error as CubeFailure {
            let category: LUTAnalysisFailureCategory
            switch error.category {
            case .invalidDimension: category = .invalidDimension
            case .resourceLimit: category = .resourceLimit
            case .invalidEncoding: category = .invalidEncoding
            case .nonFiniteValue: category = .nonFiniteValue
            case .invalidNumber: category = .invalidNumber
            default: category = .malformedHeader
            }
            throw LUTAnalysisFailure(category, offset: error.line)
        }
    }

    static func checkedNodeCount(_ dimension: CubeDimension, size: Int) throws -> Int {
        do {
            return try CubeParser.checkedNodeCount(dimension: dimension, size: size, line: 0)
        } catch let error as CubeFailure {
            throw LUTAnalysisFailure(error.category == .invalidDimension ? .invalidDimension : .resourceLimit)
        }
    }

    static func metadata(_ source: String) throws -> LUTAnalysisSectionMetadata {
        var result = LUTAnalysisSectionMetadata(rawText: nil)
        var values: [String: String] = [:]
        var matrixRows: [[Double]?] = Array(repeating: nil, count: 3)
        var sawMetadata = false
        for rawLine in source.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("#") else { continue }
            let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
            guard body.hasPrefix("LA_") else { continue }
            sawMetadata = true
            let parts = body.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count == 2, values[parts[0]] == nil else {
                throw LUTAnalysisFailure(.invalidMetadata)
            }
            values[parts[0]] = parts[1]
        }
        func text(_ key: String) -> String? { values[key]?.trimmingCharacters(in: .whitespaces) }
        func scalar(_ key: String) throws -> Double? {
            guard let value = text(key) else { return nil }
            return try finiteNumber(value[...])
        }
        result.inputTransferFunction = text("LA_INPUT_TRANSFER_FUNCTION")
        result.systemColourspace = text("LA_SYSTEM_COLOURSPACE")
        result.inputColourspace = text("LA_INPUT_COLOURSPACE")
        result.inputRange = text("LA_INPUT_RANGE")
        result.inputMinimum = try scalar("LA_INPUT_MIN")
        result.inputMaximum = try scalar("LA_INPUT_MAX")
        result.interpolation = text("LA_INTERPOLATION")
        if let iso = text("LA_BASE_ISO"), iso.lowercased() != "unknown" {
            guard let value = Int(iso), value >= 0 else { throw LUTAnalysisFailure(.invalidMetadata) }
            result.baseISO = value
        }
        for (key, row) in [("LA_INPUT_MATRIX_R", 0), ("LA_INPUT_MATRIX_G", 1), ("LA_INPUT_MATRIX_B", 2)] {
            if let value = text(key) {
                let tokens = value.split(whereSeparator: \.isWhitespace)
                guard tokens.count == 3 else { throw LUTAnalysisFailure(.invalidMetadata) }
                matrixRows[row] = try tokens.map(finiteNumber)
            }
        }
        if matrixRows.contains(where: { $0 != nil }) {
            guard matrixRows.allSatisfy({ $0 != nil }) else { throw LUTAnalysisFailure(.invalidMetadata) }
            result.inputMatrix = try Matrix3x3(rowMajor: matrixRows.compactMap { $0 }.flatMap { $0 })
        }
        if sawMetadata { result.rawText = source }
        return result
    }

    static func metadataLines(_ metadata: LUTAnalysisSectionMetadata) -> [String] {
        var lines: [String] = []
        if let value = metadata.inputTransferFunction { lines.append("# LA_INPUT_TRANSFER_FUNCTION \(value)") }
        if let value = metadata.systemColourspace { lines.append("# LA_SYSTEM_COLOURSPACE \(value)") }
        if let value = metadata.inputColourspace { lines.append("# LA_INPUT_COLOURSPACE \(value)") }
        if let value = metadata.inputRange { lines.append("# LA_INPUT_RANGE \(value)") }
        if let value = metadata.inputMinimum { lines.append("# LA_INPUT_MIN \(String(value))") }
        if let value = metadata.inputMaximum { lines.append("# LA_INPUT_MAX \(String(value))") }
        if let value = metadata.interpolation { lines.append("# LA_INTERPOLATION \(value)") }
        if let value = metadata.baseISO { lines.append("# LA_BASE_ISO \(value)") }
        if let matrix = metadata.inputMatrix {
            lines.append("# LA_INPUT_MATRIX_R \(matrix[0, 0])\t\(matrix[0, 1])\t\(matrix[0, 2])")
            lines.append("# LA_INPUT_MATRIX_G \(matrix[1, 0])\t\(matrix[1, 1])\t\(matrix[1, 2])")
            lines.append("# LA_INPUT_MATRIX_B \(matrix[2, 0])\t\(matrix[2, 1])\t\(matrix[2, 2])")
        }
        return lines
    }
}

public enum LACubeParser {
    public static func parse(_ data: Data) throws -> LUTAnalysisFile {
        guard data.count <= LUTAnalysisParsing.maxFileBytes else { throw LUTAnalysisFailure(.resourceLimit) }
        guard let source = String(data: data, encoding: .utf8) else {
            throw LUTAnalysisFailure(.invalidEncoding)
        }
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { throw LUTAnalysisFailure(.malformedHeader) }
        var sections: [[String]] = [[]]
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "# -------------------------------------------------------------------------------" {
                guard sections[0].contains(where: { $0.contains("LUT_1D_SIZE") }) else {
                    throw LUTAnalysisFailure(.malformedHeader)
                }
                sections.append([])
            } else {
                sections[sections.count - 1].append(line)
            }
        }
        guard sections.count <= 2, !sections[0].isEmpty else { throw LUTAnalysisFailure(.malformedHeader) }
        let first = sections[0].joined(separator: "\n")
        let transfer = try LUTAnalysisParsing.parseCube(Data(first.utf8))
        guard transfer.dimension == .one else { throw LUTAnalysisFailure(.invalidDimension) }
        let colour: CubeLUT?
        if sections.count == 2 {
            let second = sections[1].joined(separator: "\n")
            guard !second.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LUTAnalysisFailure(.malformedHeader)
            }
            let parsed = try LUTAnalysisParsing.parseCube(Data(second.utf8))
            guard parsed.dimension == .three else { throw LUTAnalysisFailure(.invalidDimension) }
            colour = parsed
        } else {
            colour = nil
        }
        let transferMetadata = try LUTAnalysisParsing.metadata(first)
        let colourMetadata = try colour.map { _ in try LUTAnalysisParsing.metadata(sections[1].joined(separator: "\n")) }
        if let title = transfer.title, let colourTitle = colour?.title, title != colourTitle {
            throw LUTAnalysisFailure(.malformedHeader)
        }
        return LUTAnalysisFile(title: transfer.title ?? colour?.title,
                               transferLUT: transfer, colourLUT: colour,
                               transferMetadata: transferMetadata,
                               colourMetadata: colourMetadata, sourceFormat: "lacube")
    }

    public static func parse(url: URL) throws -> LUTAnalysisFile {
        try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }
}

public enum LACubeWriter {
    public static func serialize(_ file: LUTAnalysisFile) throws -> String {
        func section(_ lut: CubeLUT, metadata: LUTAnalysisSectionMetadata) throws -> String {
            var result = try CubeWriter.serialize(lut, dialect: .domain)
            let headerEnd = result.firstIndex(of: "\n") ?? result.endIndex
            let insertion = LUTAnalysisParsing.metadataLines(metadata).joined(separator: "\n")
            guard !insertion.isEmpty else { return result }
            result.insert(contentsOf: insertion + "\n", at: result.index(after: headerEnd))
            return result
        }
        var output = try section(file.transferLUT, metadata: file.transferMetadata)
        if let colour = file.colourLUT {
            output += "# -------------------------------------------------------------------------------\n"
            output += try section(colour, metadata: file.colourMetadata ?? LUTAnalysisSectionMetadata())
        }
        return output
    }
}

public enum LABinParser {
    public static func parse(_ data: Data) throws -> LUTAnalysisFile {
        guard data.count <= LUTAnalysisParsing.maxFileBytes else { throw LUTAnalysisFailure(.resourceLimit) }
        guard data.count >= 8 else { throw LUTAnalysisFailure(.truncated) }
        func int32(_ offset: Int) throws -> Int32 {
            guard offset >= 0, offset + 4 <= data.count else { throw LUTAnalysisFailure(.truncated, offset: offset) }
            let b0 = UInt32(data[offset]), b1 = UInt32(data[offset + 1])
            let b2 = UInt32(data[offset + 2]), b3 = UInt32(data[offset + 3])
            return Int32(bitPattern: b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
        }
        let tfSize = Int(try int32(0))
        let dimension = Int(try int32(4))
        guard tfSize >= 2 else { throw LUTAnalysisFailure(.invalidDimension, offset: 0) }
        guard dimension == 0 || dimension >= 2 else { throw LUTAnalysisFailure(.invalidDimension, offset: 4) }
        let tfCount = try LUTAnalysisParsing.checkedNodeCount(.one, size: tfSize)
        let colourCount = dimension == 0 ? 0 : try LUTAnalysisParsing.checkedNodeCount(.three, size: dimension)
        let (sampleWords, overflow1) = 2.addingReportingOverflow(tfCount)
        let (allWords, overflow2) = sampleWords.addingReportingOverflow(colourCount * 3)
        guard !overflow1, !overflow2, allWords <= Int.max / 4 else { throw LUTAnalysisFailure(.resourceLimit) }
        let sampleEnd = allWords * 4
        guard sampleEnd <= data.count else { throw LUTAnalysisFailure(.truncated) }
        func decoded(_ offset: Int, matrix: Bool = false) throws -> Double {
            let raw = try int32(offset)
            guard raw != LUTAnalysisParsing.sampleSentinel && raw != -LUTAnalysisParsing.sampleSentinel else {
                throw LUTAnalysisFailure(.lossyRepresentation, offset: offset)
            }
            return Double(raw) / (matrix ? LUTAnalysisParsing.matrixScale : LUTAnalysisParsing.scale)
        }
        var tf: [RGB64] = []
        tf.reserveCapacity(tfCount)
        for index in 0..<tfCount {
            let value = try decoded((2 + index) * 4)
            try tf.append(RGB64(value, value, value))
        }
        var colourSamples: [RGB64] = []
        if colourCount > 0 {
            colourSamples.reserveCapacity(colourCount)
            let base = 2 + tfCount
            for index in 0..<colourCount {
                try colourSamples.append(RGB64(try decoded((base + index) * 4),
                                                try decoded((base + colourCount + index) * 4),
                                                try decoded((base + 2 * colourCount + index) * 4)))
            }
        }
        var cursor = sampleEnd
        var matrix: Matrix3x3?
        let remaining = data.count - cursor
        func printable(_ start: Int) -> Bool {
            guard start <= data.count else { return false }
            return data[start..<data.count].allSatisfy { $0 == 9 || $0 == 10 || $0 == 13 || (32...126).contains($0) }
        }
        if remaining > 0 && !printable(cursor) {
            guard remaining >= 36 else { throw LUTAnalysisFailure(.invalidLength, offset: cursor) }
            var values: [Double] = []
            for index in 0..<9 { values.append(try decoded(cursor + index * 4, matrix: true)) }
            if values.contains(where: { $0 != 0 }) { matrix = try Matrix3x3(rowMajor: values) }
            cursor += 36
        }
        guard printable(cursor) else { throw LUTAnalysisFailure(.invalidEncoding, offset: cursor) }
        let metadataText = String(decoding: data[cursor..<data.count], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = try LABinParser.metadata(metadataText, matrix: matrix)
        let transfer: CubeLUT
        do {
            transfer = try CubeLUT(dimension: .one, size: tfSize, domain: .unit, samples: tf)
        } catch { throw LUTAnalysisFailure(.invalidDimension) }
        let colourLUT: CubeLUT?
        if colourCount == 0 {
            colourLUT = nil
        } else {
            do {
                colourLUT = try CubeLUT(dimension: .three, size: dimension, domain: .unit, samples: colourSamples)
            } catch { throw LUTAnalysisFailure(.invalidDimension) }
        }
        return LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colourLUT,
                               transferMetadata: metadata.transfer,
                               colourMetadata: colourLUT == nil ? nil : metadata.colour,
                               sourceFormat: "labin")
    }

    private static func metadata(_ text: String, matrix: Matrix3x3?) throws ->
        (transfer: LUTAnalysisSectionMetadata, colour: LUTAnalysisSectionMetadata) {
        guard !text.isEmpty else {
            let transfer = LUTAnalysisSectionMetadata(rawText: nil)
            let colour = LUTAnalysisSectionMetadata(inputMatrix: matrix, rawText: nil)
            return (transfer, colour)
        }
        var transfer = LUTAnalysisSectionMetadata(rawText: text)
        var colour = LUTAnalysisSectionMetadata(inputMatrix: matrix, rawText: text)
        let parts = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count % 2 == 0 else { throw LUTAnalysisFailure(.invalidMetadata) }
        for index in stride(from: 0, to: parts.count, by: 2) {
            let key = parts[index].trimmingCharacters(in: .whitespaces)
            let value = parts[index + 1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "1DTF": transfer.inputTransferFunction = value
            case "1DRG": transfer.inputRange = value
            case "1DMIN": transfer.inputMinimum = try LUTAnalysisParsing.finiteNumber(value[...])
            case "1DMAX": transfer.inputMaximum = try LUTAnalysisParsing.finiteNumber(value[...])
            case "SYSCS":
                transfer.systemColourspace = value
                colour.systemColourspace = colour.systemColourspace ?? value
            case "3DSYSCS": colour.systemColourspace = value
            case "3DTF": colour.inputTransferFunction = value
            case "3DCS": colour.inputColourspace = value
            case "3DRG": colour.inputRange = value
            case "3DMIN": colour.inputMinimum = try LUTAnalysisParsing.finiteNumber(value[...])
            case "3DMAX": colour.inputMaximum = try LUTAnalysisParsing.finiteNumber(value[...])
            case "INTERPOLATION":
                transfer.interpolation = value
                colour.interpolation = colour.interpolation ?? value
            case "3DINTERPOLATION": colour.interpolation = value
            case "BASEISO":
                if value.lowercased() != "unknown" {
                    guard let iso = Int(value), iso >= 0 else { throw LUTAnalysisFailure(.invalidMetadata) }
                    transfer.baseISO = iso
                    colour.baseISO = colour.baseISO ?? iso
                }
            case "3DBASEISO":
                if value.lowercased() != "unknown" {
                    guard let iso = Int(value), iso >= 0 else { throw LUTAnalysisFailure(.invalidMetadata) }
                    colour.baseISO = iso
                }
            default: break
            }
        }
        return (transfer, colour)
    }

    public static func parse(url: URL) throws -> LUTAnalysisFile {
        try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }
}

public enum LABinWriter {
    public static func serialize(_ file: LUTAnalysisFile) throws -> Data {
        let transfer = file.transferLUT
        guard transfer.dimension == .one, transfer.shaper == nil else { throw LUTAnalysisFailure(.unsupported) }
        if let colour = file.colourLUT, colour.dimension != .three { throw LUTAnalysisFailure(.invalidDimension) }
        let dimension = file.colourLUT?.size ?? 0
        let colourSamples = file.colourLUT?.samples ?? []
        var bytes: [UInt8] = []
        func appendInt32(_ value: Int32) {
            let bits = UInt32(bitPattern: value)
            bytes += [UInt8(bits & 255), UInt8((bits >> 8) & 255), UInt8((bits >> 16) & 255), UInt8((bits >> 24) & 255)]
        }
        func quantize(_ value: Double, matrix: Bool = false) throws -> Int32 {
            guard value.isFinite else { throw LUTAnalysisFailure(.nonFiniteValue) }
            let limit = matrix ? 19.9 : 1.99
            guard abs(value) < limit else { throw LUTAnalysisFailure(.lossyRepresentation) }
            let scaled = value * (matrix ? LUTAnalysisParsing.matrixScale : LUTAnalysisParsing.scale)
            guard scaled.isFinite, scaled >= Double(Int32.min), scaled <= Double(Int32.max) else { throw LUTAnalysisFailure(.lossyRepresentation) }
            let rounded = floor(scaled + 0.5)
            guard rounded >= Double(Int32.min), rounded <= Double(Int32.max) else { throw LUTAnalysisFailure(.lossyRepresentation) }
            return Int32(rounded)
        }
        appendInt32(Int32(transfer.size)); appendInt32(Int32(dimension))
        for sample in transfer.samples { appendInt32(try quantize(sample.r)) }
        for channel in 0..<3 { for sample in colourSamples { appendInt32(try quantize(sample[channel])) } }
        let matrix = file.colourMetadata?.inputMatrix
        for index in 0..<9 { appendInt32(try quantize(matrix?.rowMajor[index] ?? 0, matrix: true)) }
        let transferMetadata = file.transferMetadata
        let colourMetadata = file.colourMetadata
        var pairs: [String] = []
        if let value = transferMetadata.inputTransferFunction { pairs += ["1DTF", value] }
        if let value = transferMetadata.inputRange { pairs += ["1DRG", value] }
        if let value = transferMetadata.inputMinimum { pairs += ["1DMIN", String(value)] }
        if let value = transferMetadata.inputMaximum { pairs += ["1DMAX", String(value)] }
        if let value = transferMetadata.systemColourspace { pairs += ["SYSCS", value] }
        if let value = transferMetadata.interpolation { pairs += ["INTERPOLATION", value] }
        if let value = transferMetadata.baseISO { pairs += ["BASEISO", String(value)] }
        if let metadata = colourMetadata {
            if let value = metadata.systemColourspace,
               value != transferMetadata.systemColourspace { pairs += ["3DSYSCS", value] }
            if let value = metadata.inputTransferFunction { pairs += ["3DTF", value] }
            if let value = metadata.inputColourspace { pairs += ["3DCS", value] }
            if let value = metadata.inputRange { pairs += ["3DRG", value] }
            if let value = metadata.inputMinimum { pairs += ["3DMIN", String(value)] }
            if let value = metadata.inputMaximum { pairs += ["3DMAX", String(value)] }
            if let value = metadata.interpolation,
               value != transferMetadata.interpolation { pairs += ["3DINTERPOLATION", value] }
            if let value = metadata.baseISO,
               value != transferMetadata.baseISO { pairs += ["3DBASEISO", String(value)] }
        }
        let text = pairs.joined(separator: "|")
        guard text.unicodeScalars.allSatisfy({ $0.value < 128 }) else { throw LUTAnalysisFailure(.invalidMetadata) }
        bytes.append(contentsOf: text.utf8)
        while bytes.count % 4 != 0 { bytes.append(32) }
        return Data(bytes)
    }
}
