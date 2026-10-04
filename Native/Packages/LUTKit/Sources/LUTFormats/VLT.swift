import Foundation
import LUTCore

public enum VLTFailureCategory: String, Equatable, Sendable {
    case malformedHeader
    case unsupported
    case invalidNumber
    case nonFiniteValue
    case invalidCodeValue
    case rowCountMismatch
    case lossyRepresentation
    case resourceLimit
    case invalidEncoding
}

public struct VLTFailure: Error, Equatable, Sendable {
    public let category: VLTFailureCategory
    public let line: Int

    public init(_ category: VLTFailureCategory, line: Int = 0) {
        self.category = category
        self.line = line
    }
}

public enum VLTParser {
    public static let size = 17
    public static let codeMax = 4095
    private static let expectedRows = size * size * size
    private static let maxFileBytes = 1024 * 1024

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw VLTFailure(.resourceLimit) }
        guard let text = String(data: data, encoding: .utf8) else { throw VLTFailure(.invalidEncoding) }
        var versionSeen = false
        var sourceSeen = false
        var sizeSeen = false
        var samples: [RGB64] = []
        samples.reserveCapacity(expectedRows)

        for (offset, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = offset + 1
            let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { continue }
            if content.hasPrefix("#") {
                guard samples.isEmpty else { throw VLTFailure(.malformedHeader, line: line) }
                if content == "# panasonic vlt file version 1.0", !versionSeen {
                    versionSeen = true
                } else if content == "# source vlt file \"\"", !sourceSeen {
                    sourceSeen = true
                } else {
                    throw VLTFailure(.unsupported, line: line)
                }
                continue
            }
            let tokens = content.split(whereSeparator: \.isWhitespace)
            if !sizeSeen {
                guard tokens.first == "LUT_3D_SIZE" else { throw VLTFailure(.malformedHeader, line: line) }
                guard tokens.count == 2, let declared = Int(tokens[1]) else {
                    throw VLTFailure(.malformedHeader, line: line)
                }
                guard declared == size else { throw VLTFailure(.unsupported, line: line) }
                guard versionSeen, sourceSeen else { throw VLTFailure(.malformedHeader, line: line) }
                sizeSeen = true
                continue
            }
            guard tokens.count == 3 else { throw VLTFailure(.invalidNumber, line: line) }
            let values = try tokens.map { token -> Double in
                guard let integer = Int(token) else {
                    if let floating = Double(token), !floating.isFinite {
                        throw VLTFailure(.nonFiniteValue, line: line)
                    }
                    throw VLTFailure(.invalidNumber, line: line)
                }
                guard (0...codeMax).contains(integer) else {
                    throw VLTFailure(.invalidCodeValue, line: line)
                }
                return Double(integer) / Double(codeMax)
            }
            guard samples.count < expectedRows else { throw VLTFailure(.rowCountMismatch, line: line) }
            samples.append(try RGB64(values[0], values[1], values[2]))
        }
        guard sizeSeen else { throw VLTFailure(.malformedHeader) }
        guard samples.count == expectedRows else { throw VLTFailure(.rowCountMismatch) }
        return try CubeLUT(dimension: .three, size: size, domain: .unit, samples: samples)
    }
}

public enum VLTWriter {
    public static func header() -> String {
        "# panasonic vlt file version 1.0\n# source vlt file \"\"\nLUT_3D_SIZE 17\n\n"
    }

    public static func row(_ sample: RGB64) throws -> String {
        var codes: [String] = []
        for channel in 0..<3 {
            let value = sample[channel]
            guard value.isFinite, (0...1).contains(value) else {
                throw VLTFailure(.lossyRepresentation)
            }
            let integer = Int((value * Double(VLTParser.codeMax)).rounded(.toNearestOrAwayFromZero))
            codes.append(String(integer))
        }
        return codes.joined(separator: " ") + "\n"
    }

    public static func serialize(_ lut: CubeLUT) throws -> String {
        guard lut.dimension == .three, lut.size == VLTParser.size, lut.shaper == nil,
              lut.title == nil,
              lut.domain.min.r.bitPattern == 0, lut.domain.min.g.bitPattern == 0,
              lut.domain.min.b.bitPattern == 0,
              lut.domain.max.r.bitPattern == 1.0.bitPattern,
              lut.domain.max.g.bitPattern == 1.0.bitPattern,
              lut.domain.max.b.bitPattern == 1.0.bitPattern else {
            throw VLTFailure(.lossyRepresentation)
        }
        var text = header()
        text.reserveCapacity(72_000)
        for sample in lut.samples {
            text += try row(sample)
        }
        return text
    }
}
