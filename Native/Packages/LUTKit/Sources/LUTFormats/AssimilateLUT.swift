import Foundation
import LUTCore

public enum AssimilateLUTFailureCategory: String, Equatable, Sendable {
    case malformedHeader
    case unsupported
    case invalidEncoding
    case invalidNumber
    case nonFiniteValue
    case rowCountMismatch
    case resourceLimit
    case lossyRepresentation
}

public struct AssimilateLUTFailure: Error, Equatable, Sendable {
    public let category: AssimilateLUTFailureCategory
    public let line: Int

    public init(_ category: AssimilateLUTFailureCategory, line: Int = 0) {
        self.category = category
        self.line = line
    }
}

public enum AssimilateLUTParser {
    public static let maxSize = 16_384
    public static let maxFileBytes = 2 * 1024 * 1024
    static let maxCode = 2_147_483_647

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw AssimilateLUTFailure(.resourceLimit) }
        guard let text = String(data: data, encoding: .utf8) else {
            throw AssimilateLUTFailure(.invalidEncoding)
        }
        var header: (channels: Int, size: Int)?
        var codes: [Int] = []

        for (offset, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = offset + 1
            let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { continue }
            if header == nil {
                if content.hasPrefix("#") { continue }
                let tokens = content.split(whereSeparator: \.isWhitespace)
                guard tokens.count == 3, tokens[0] == "LUT:",
                      let channels = Int(tokens[1]), let size = Int(tokens[2]) else {
                    throw AssimilateLUTFailure(.malformedHeader, line: line)
                }
                guard channels == 1 || channels == 3, (2...maxSize).contains(size) else {
                    throw AssimilateLUTFailure(.unsupported, line: line)
                }
                header = (channels, size)
                codes.reserveCapacity(channels * size)
                continue
            }
            guard let header else { throw AssimilateLUTFailure(.malformedHeader, line: line) }
            guard codes.count < header.channels * header.size else {
                throw AssimilateLUTFailure(.rowCountMismatch, line: line)
            }
            if content.hasPrefix("#") { throw AssimilateLUTFailure(.unsupported, line: line) }
            guard let code = Int(content) else {
                if let value = Double(content), !value.isFinite {
                    throw AssimilateLUTFailure(.nonFiniteValue, line: line)
                }
                throw AssimilateLUTFailure(.invalidNumber, line: line)
            }
            guard (-maxCode...maxCode).contains(code) else {
                throw AssimilateLUTFailure(.unsupported, line: line)
            }
            codes.append(code)
        }
        guard let header else { throw AssimilateLUTFailure(.malformedHeader) }
        guard codes.count == header.channels * header.size else {
            throw AssimilateLUTFailure(.rowCountMismatch)
        }
        let divisor = Double(header.size - 1)
        var samples: [RGB64] = []
        samples.reserveCapacity(header.size)
        for index in 0..<header.size {
            let red = Double(codes[index]) / divisor
            let green = header.channels == 1 ? red : Double(codes[index + header.size]) / divisor
            let blue = header.channels == 1 ? red : Double(codes[index + 2 * header.size]) / divisor
            samples.append(try RGB64(red, green, blue))
        }
        return try CubeLUT(dimension: .one, size: header.size, domain: .unit, samples: samples)
    }
}

public enum AssimilateLUTWriter {
    public static func isExactUnitDomain(_ domain: LUTDomain) -> Bool {
        domain.min.r.bitPattern == 0 && domain.min.g.bitPattern == 0 &&
        domain.min.b.bitPattern == 0 &&
        domain.max.r.bitPattern == 1.0.bitPattern &&
        domain.max.g.bitPattern == 1.0.bitPattern &&
        domain.max.b.bitPattern == 1.0.bitPattern
    }

    public static func serialize(_ lut: CubeLUT) throws -> String {
        guard lut.dimension == .one, (2...AssimilateLUTParser.maxSize).contains(lut.size),
              lut.title == nil, lut.shaper == nil,
              isExactUnitDomain(lut.domain) else {
            throw AssimilateLUTFailure(.lossyRepresentation)
        }
        var output = "LUT: 3 \(lut.size)\n"
        output.reserveCapacity(lut.size * 36)
        let divisor = Double(lut.size - 1)
        for channel in 0..<3 {
            for sample in lut.samples {
                let scaled = sample[channel] * divisor
                guard scaled.isFinite, abs(scaled) <= Double(AssimilateLUTParser.maxCode) else {
                    throw AssimilateLUTFailure(.lossyRepresentation)
                }
                // JavaScript Math.round breaks negative half ties toward positive infinity.
                let rounded = floor(scaled + 0.5)
                guard rounded.isFinite,
                      abs(rounded) <= Double(AssimilateLUTParser.maxCode) else {
                    throw AssimilateLUTFailure(.lossyRepresentation)
                }
                output += String(Int(rounded)) + "\n"
            }
        }
        return output
    }
}
