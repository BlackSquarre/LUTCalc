import Foundation
import LUTCore

public enum ILUTFailureCategory: String, Equatable, Sendable {
    case invalidEncoding
    case invalidNumber
    case nonFiniteValue
    case invalidCodeValue
    case unsupported
    case rowCountMismatch
    case resourceLimit
    case lossyRepresentation
}

public struct ILUTFailure: Error, Equatable, Sendable {
    public let category: ILUTFailureCategory
    public let line: Int

    public init(_ category: ILUTFailureCategory, line: Int = 0) {
        self.category = category
        self.line = line
    }
}

public enum ILUTParser {
    public static let size = 16_384
    public static let codeMax = 16_383
    private static let maxFileBytes = 4 * 1024 * 1024

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw ILUTFailure(.resourceLimit) }
        var samples: [RGB64] = []
        samples.reserveCapacity(size)
        var line = 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(64)

        func parseLine(_ raw: [UInt8]) throws {
            line += 1
            guard let text = String(bytes: raw, encoding: .utf8) else {
                throw ILUTFailure(.invalidEncoding, line: line)
            }
            let tokens = text.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard tokens.count == 4 else {
                throw ILUTFailure(samples.count == size ? .rowCountMismatch : .invalidNumber, line: line)
            }
            guard samples.count < size else { throw ILUTFailure(.rowCountMismatch, line: line) }
            var codes: [Int] = []
            codes.reserveCapacity(4)
            for token in tokens {
                let lower = token.lowercased()
                if ["nan", "+nan", "-nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"].contains(lower) {
                    throw ILUTFailure(.nonFiniteValue, line: line)
                }
                guard let value = Int(token) else { throw ILUTFailure(.invalidNumber, line: line) }
                codes.append(value)
            }
            guard codes[3] == 0 else { throw ILUTFailure(.unsupported, line: line) }
            guard codes[0...2].allSatisfy({ (0...codeMax).contains($0) }) else {
                throw ILUTFailure(.invalidCodeValue, line: line)
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
                guard bytes.count < 4096 else { throw ILUTFailure(.resourceLimit, line: line + 1) }
                bytes.append(byte)
            }
        }
        if !bytes.isEmpty { try parseLine(bytes) }
        guard samples.count == size else { throw ILUTFailure(.rowCountMismatch, line: line) }
        return try CubeLUT(dimension: .one, size: size, domain: .unit, samples: samples)
    }
}

public enum ILUTWriter {
    public static func serialize(_ lut: CubeLUT) throws -> String {
        guard lut.dimension == .one, lut.size == ILUTParser.size,
              lut.title == nil, lut.shaper == nil,
              lut.domain.min.r.bitPattern == 0, lut.domain.min.g.bitPattern == 0,
              lut.domain.min.b.bitPattern == 0,
              lut.domain.max.r.bitPattern == 1.0.bitPattern,
              lut.domain.max.g.bitPattern == 1.0.bitPattern,
              lut.domain.max.b.bitPattern == 1.0.bitPattern else {
            throw ILUTFailure(.lossyRepresentation)
        }
        var output = String()
        output.reserveCapacity(16_384 * 28)
        for sample in lut.samples {
            var codes: [String] = []
            for channel in 0..<3 {
                let value = sample[channel]
                guard value.isFinite, (0...1).contains(value) else {
                    throw ILUTFailure(.lossyRepresentation)
                }
                let code = Int((value * Double(ILUTParser.codeMax)).rounded(.toNearestOrAwayFromZero))
                codes.append(String(code))
            }
            output += codes.joined(separator: ",") + ",0\n"
        }
        return output
    }
}
