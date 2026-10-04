import Foundation
import LUTCore

public enum SPI3DFailureCategory: String, Equatable, Sendable {
    case malformedHeader
    case invalidEncoding
    case invalidDimension
    case invalidIndex
    case invalidNumber
    case nonFiniteValue
    case rowCountMismatch
    case duplicateIndex
    case resourceLimit
    case lossyRepresentation
    case unsupported
}

public struct SPI3DFailure: Error, Equatable, Sendable {
    public let category: SPI3DFailureCategory
    public let line: Int

    public init(_ category: SPI3DFailureCategory, line: Int) {
        self.category = category
        self.line = line
    }
}

public enum SPI3DParser {
    public static let maxFileBytes = CubeParser.maxFileBytes
    private static let maxLineBytes = 1024 * 1024

    public static func parse(url: URL) throws -> CubeLUT {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.int64Value > maxFileBytes {
            throw SPI3DFailure(.resourceLimit, line: 0)
        }
        return try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw SPI3DFailure(.resourceLimit, line: 0) }
        var stage = 0
        var size = 0
        var samples: [RGB64] = []
        var seen: [Bool] = []
        var accepted = 0
        var lineNumber = 0
        var lineBytes: [UInt8] = []

        func processLine() throws {
            lineNumber += 1
            if lineBytes.last == 13 { lineBytes.removeLast() }
            guard let source = String(bytes: lineBytes, encoding: .utf8) else {
                throw SPI3DFailure(.invalidEncoding, line: lineNumber)
            }
            lineBytes.removeAll(keepingCapacity: true)
            let content = source.trimmingCharacters(in: .whitespaces)
            if content.isEmpty || content.hasPrefix("#") { return }
            let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
            switch stage {
            case 0:
                guard content == "SPILUT 1.0" else { throw SPI3DFailure(.unsupported, line: lineNumber) }
                stage = 1
            case 1:
                guard content == "3 3" else { throw SPI3DFailure(.unsupported, line: lineNumber) }
                stage = 2
            case 2:
                guard tokens.count == 3 else { throw SPI3DFailure(.malformedHeader, line: lineNumber) }
                guard let red = Int(tokens[0]), let green = Int(tokens[1]), let blue = Int(tokens[2]) else {
                    throw SPI3DFailure(.resourceLimit, line: lineNumber)
                }
                guard red == green, green == blue else { throw SPI3DFailure(.unsupported, line: lineNumber) }
                guard red >= 2 else { throw SPI3DFailure(.invalidDimension, line: lineNumber) }
                let count: Int
                do { count = try CubeParser.checkedNodeCount(dimension: .three, size: red, line: lineNumber) }
                catch { throw SPI3DFailure(.resourceLimit, line: lineNumber) }
                size = red
                samples = Array(repeating: try RGB64(0, 0, 0), count: count)
                seen = Array(repeating: false, count: count)
                stage = 3
            default:
                guard tokens.count == 6 else { throw SPI3DFailure(.invalidNumber, line: lineNumber) }
                guard let red = Int(tokens[0]), let green = Int(tokens[1]), let blue = Int(tokens[2]),
                      tokens[0].allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "-" || $0 == "+") }),
                      tokens[1].allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "-" || $0 == "+") }),
                      tokens[2].allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "-" || $0 == "+") }) else {
                    throw SPI3DFailure(.invalidIndex, line: lineNumber)
                }
                guard (0..<size).contains(red), (0..<size).contains(green), (0..<size).contains(blue) else {
                    throw SPI3DFailure(.invalidIndex, line: lineNumber)
                }
                let index = red + size * (green + size * blue)
                guard !seen[index] else { throw SPI3DFailure(.duplicateIndex, line: lineNumber) }
                let values = try tokens[3...5].map { token -> Double in
                    do { return try SPI1DParser.number(token, line: lineNumber) }
                    catch let error as SPI1DFailure {
                        throw SPI3DFailure(error.category == .nonFiniteValue ? .nonFiniteValue : .invalidNumber,
                                           line: lineNumber)
                    }
                }
                samples[index] = try RGB64(values[0], values[1], values[2])
                seen[index] = true
                accepted += 1
            }
        }

        for byte in data {
            if byte == 10 {
                try processLine()
            } else {
                guard lineBytes.count < maxLineBytes else { throw SPI3DFailure(.resourceLimit, line: lineNumber + 1) }
                lineBytes.append(byte)
            }
        }
        if !lineBytes.isEmpty { try processLine() }
        guard stage == 3 else { throw SPI3DFailure(.malformedHeader, line: lineNumber) }
        guard accepted == samples.count else { throw SPI3DFailure(.rowCountMismatch, line: lineNumber) }
        return try CubeLUT(dimension: .three, size: size, domain: .unit, samples: samples)
    }
}

public enum SPI3DWriter {
    public static func header(size: Int) -> String {
        "SPILUT 1.0\n3 3\n\(size) \(size) \(size)\n"
    }

    public static func row(red: Int, green: Int, blue: Int, sample: RGB64) -> String {
        "\(red) \(green) \(blue) \(sample.r) \(sample.g) \(sample.b)\n"
    }

    public static func serialize(_ lut: CubeLUT) throws -> String {
        let lower = lut.domain.min
        let upper = lut.domain.max
        guard lut.dimension == .three, lut.shaper == nil, lut.title == nil,
              lower.r.bitPattern == 0, lower.g.bitPattern == 0, lower.b.bitPattern == 0,
              upper.r.bitPattern == 1.0.bitPattern,
              upper.g.bitPattern == 1.0.bitPattern,
              upper.b.bitPattern == 1.0.bitPattern else {
            throw SPI3DFailure(.lossyRepresentation, line: 0)
        }
        let size = lut.size
        var text = header(size: size)
        for red in 0..<size {
            for green in 0..<size {
                for blue in 0..<size {
                    let sample = lut.samples[red + size * (green + size * blue)]
                    text += row(red: red, green: green, blue: blue, sample: sample)
                }
            }
        }
        return text
    }
}
