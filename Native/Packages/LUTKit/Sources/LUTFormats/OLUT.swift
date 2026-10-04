import Foundation
import LUTCore

public enum OLUTFailureCategory: String, Equatable, Sendable {
    case invalidEncoding
    case invalidNumber
    case nonFiniteValue
    case invalidCodeValue
    case unsupported
    case rowCountMismatch
    case resourceLimit
    case lossyRepresentation
}

public struct OLUTFailure: Error, Equatable, Sendable {
    public let category: OLUTFailureCategory
    public let line: Int

    public init(_ category: OLUTFailureCategory, line: Int = 0) {
        self.category = category
        self.line = line
    }
}

public enum OLUTParser {
    public static let size = 4_096
    public static let codeMax = 4_095
    private static let maxFileBytes = 2 * 1024 * 1024

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw OLUTFailure(.resourceLimit) }
        var samples: [RGB64] = []
        samples.reserveCapacity(size)
        var line = 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(128)

        func parseLine(_ raw: [UInt8]) throws {
            line += 1
            guard let text = String(bytes: raw, encoding: .utf8) else {
                throw OLUTFailure(.invalidEncoding, line: line)
            }
            let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty || content.hasPrefix("#") { return }
            let tokens = content.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard tokens.count == 6 else {
                throw OLUTFailure(samples.count == size ? .rowCountMismatch : .invalidNumber, line: line)
            }
            guard samples.count < size else { throw OLUTFailure(.rowCountMismatch, line: line) }
            var codes: [Int] = []
            codes.reserveCapacity(6)
            for token in tokens {
                let lower = token.lowercased()
                if ["nan", "+nan", "-nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"].contains(lower) {
                    throw OLUTFailure(.nonFiniteValue, line: line)
                }
                guard let value = Int(token) else { throw OLUTFailure(.invalidNumber, line: line) }
                codes.append(value)
            }
            guard codes[0] == codes[3], codes[1] == codes[4], codes[2] == codes[5] else {
                throw OLUTFailure(.unsupported, line: line)
            }
            guard codes[0..<3].allSatisfy({ (0...codeMax).contains($0) }) else {
                throw OLUTFailure(.invalidCodeValue, line: line)
            }
            samples.append(try RGB64(Double(codes[0]) / Double(codeMax),
                                     Double(codes[1]) / Double(codeMax),
                                     Double(codes[2]) / Double(codeMax)))
        }

        for byte in data {
            if byte == 10 {
                var row = bytes
                if row.last == 13 { row.removeLast() }
                try parseLine(row)
                bytes.removeAll(keepingCapacity: true)
            } else {
                guard bytes.count < 4096 else { throw OLUTFailure(.resourceLimit, line: line + 1) }
                bytes.append(byte)
            }
        }
        if !bytes.isEmpty { try parseLine(bytes) }
        guard samples.count == size else { throw OLUTFailure(.rowCountMismatch, line: line) }
        return try CubeLUT(dimension: .one, size: size, domain: .unit, samples: samples)
    }
}

public enum OLUTWriter {
    public static func serialize(_ lut: CubeLUT) throws -> String {
        guard lut.dimension == .one, lut.size == OLUTParser.size,
              lut.title == nil, lut.shaper == nil,
              lut.domain.min.r.bitPattern == 0, lut.domain.min.g.bitPattern == 0,
              lut.domain.min.b.bitPattern == 0,
              lut.domain.max.r.bitPattern == 1.0.bitPattern,
              lut.domain.max.g.bitPattern == 1.0.bitPattern,
              lut.domain.max.b.bitPattern == 1.0.bitPattern else {
            throw OLUTFailure(.lossyRepresentation)
        }
        var output = String()
        output.reserveCapacity(4_096 * 48)
        for sample in lut.samples {
            var codes: [String] = []
            codes.reserveCapacity(3)
            for channel in 0..<3 {
                let value = sample[channel]
                guard value.isFinite, (0...1).contains(value) else {
                    throw OLUTFailure(.lossyRepresentation)
                }
                let code = Int((value * Double(OLUTParser.codeMax)).rounded(.toNearestOrAwayFromZero))
                codes.append(String(code))
            }
            let row = codes.joined(separator: ",")
            output += row + "," + row + "\n"
        }
        return output
    }
}
