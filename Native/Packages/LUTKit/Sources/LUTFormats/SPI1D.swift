import Foundation
import LUTCore

public enum SPI1DFailureCategory: String, Equatable, Sendable {
    case malformedHeader
    case invalidEncoding
    case invalidDimension
    case invalidComponents
    case invalidDomain
    case invalidNumber
    case nonFiniteValue
    case rowCountMismatch
    case resourceLimit
    case lossyRepresentation
    case unsupported
}

public struct SPI1DFailure: Error, Equatable, Sendable {
    public let category: SPI1DFailureCategory
    public let line: Int

    public init(_ category: SPI1DFailureCategory, line: Int) {
        self.category = category
        self.line = line
    }
}

public struct SPI1DFile: Equatable, Sendable {
    public let lut: CubeLUT
    public let components: Int

    public init(lut: CubeLUT, components: Int = 3) throws {
        guard (1...3).contains(components) else { throw SPI1DFailure(.invalidComponents, line: 0) }
        guard lut.dimension == .one, lut.shaper == nil, lut.title == nil else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        let lower = lut.domain.min
        let upper = lut.domain.max
        guard lower.r.bitPattern == lower.g.bitPattern, lower.r.bitPattern == lower.b.bitPattern,
              upper.r.bitPattern == upper.g.bitPattern, upper.r.bitPattern == upper.b.bitPattern else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        for sample in lut.samples {
            if components == 1 {
                guard sample.r.bitPattern == sample.g.bitPattern,
                      sample.r.bitPattern == sample.b.bitPattern else {
                    throw SPI1DFailure(.lossyRepresentation, line: 0)
                }
            } else if components == 2 {
                guard sample.b.bitPattern == 0 else { throw SPI1DFailure(.lossyRepresentation, line: 0) }
            }
        }
        self.lut = lut
        self.components = components
    }
}

public enum SPI1DParser {
    public static let maxFileBytes = CubeParser.maxFileBytes
    private static let maxLineBytes = 1024 * 1024

    public static func parse(url: URL) throws -> SPI1DFile {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.int64Value > maxFileBytes {
            throw SPI1DFailure(.resourceLimit, line: 0)
        }
        return try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public static func parse(_ data: Data) throws -> SPI1DFile {
        guard data.count <= maxFileBytes else { throw SPI1DFailure(.resourceLimit, line: 0) }
        var versionSeen = false
        var from: (Double, Double)?
        var size: Int?
        var components: Int?
        var samples: [RGB64] = []
        var state = 0 // header, rows, closed
        var lineNumber = 0
        var lineBytes: [UInt8] = []

        func processLine() throws {
            lineNumber += 1
            if lineBytes.last == 13 { lineBytes.removeLast() }
            guard let source = String(bytes: lineBytes, encoding: .utf8) else {
                throw SPI1DFailure(.invalidEncoding, line: lineNumber)
            }
            lineBytes.removeAll(keepingCapacity: true)
            let content = source.trimmingCharacters(in: .whitespaces)
            if content.isEmpty || content.hasPrefix("#") { return }
            let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
            if state == 0 {
                if content == "{" {
                    guard versionSeen, size != nil, components != nil else {
                        throw SPI1DFailure(.malformedHeader, line: lineNumber)
                    }
                    state = 1
                    samples.reserveCapacity(size!)
                    return
                }
                switch tokens[0] {
                case "Version":
                    guard !versionSeen, tokens.count == 2 else { throw SPI1DFailure(.malformedHeader, line: lineNumber) }
                    guard tokens[1] == "1" else { throw SPI1DFailure(.unsupported, line: lineNumber) }
                    versionSeen = true
                case "From":
                    guard from == nil, tokens.count == 3 else { throw SPI1DFailure(.malformedHeader, line: lineNumber) }
                    let lower = try number(tokens[1], line: lineNumber)
                    let upper = try number(tokens[2], line: lineNumber)
                    guard lower < upper else { throw SPI1DFailure(.invalidDomain, line: lineNumber) }
                    from = (lower, upper)
                case "Length":
                    guard size == nil, tokens.count == 2 else { throw SPI1DFailure(.malformedHeader, line: lineNumber) }
                    guard let parsed = Int(tokens[1]) else { throw SPI1DFailure(.resourceLimit, line: lineNumber) }
                    guard parsed >= 2 else { throw SPI1DFailure(.invalidDimension, line: lineNumber) }
                    do { _ = try CubeParser.checkedNodeCount(dimension: .one, size: parsed, line: lineNumber) }
                    catch { throw SPI1DFailure(.resourceLimit, line: lineNumber) }
                    size = parsed
                case "Components":
                    guard components == nil, tokens.count == 2 else { throw SPI1DFailure(.malformedHeader, line: lineNumber) }
                    guard let parsed = Int(tokens[1]), (1...3).contains(parsed) else {
                        throw SPI1DFailure(.invalidComponents, line: lineNumber)
                    }
                    components = parsed
                default:
                    throw SPI1DFailure(.malformedHeader, line: lineNumber)
                }
                return
            }
            if state == 2 { throw SPI1DFailure(.malformedHeader, line: lineNumber) }
            if content == "}" {
                guard samples.count == size else { throw SPI1DFailure(.rowCountMismatch, line: lineNumber) }
                state = 2
                return
            }
            guard samples.count < size! else { throw SPI1DFailure(.rowCountMismatch, line: lineNumber) }
            guard tokens.count == components! else { throw SPI1DFailure(.invalidNumber, line: lineNumber) }
            let values = try tokens.map { try number($0, line: lineNumber) }
            switch components! {
            case 1: samples.append(try RGB64(values[0], values[0], values[0]))
            case 2: samples.append(try RGB64(values[0], values[1], 0))
            default: samples.append(try RGB64(values[0], values[1], values[2]))
            }
        }

        for byte in data {
            if byte == 10 {
                try processLine()
            } else {
                guard lineBytes.count < maxLineBytes else { throw SPI1DFailure(.resourceLimit, line: lineNumber + 1) }
                lineBytes.append(byte)
            }
        }
        if !lineBytes.isEmpty { try processLine() }
        guard state == 2 else { throw SPI1DFailure(state == 1 ? .rowCountMismatch : .malformedHeader, line: lineNumber) }
        let range = from ?? (0, 1)
        let domain = try LUTDomain(min: RGB64(range.0, range.0, range.0),
                                   max: RGB64(range.1, range.1, range.1))
        let lut = try CubeLUT(dimension: .one, size: size!, domain: domain, samples: samples)
        return try SPI1DFile(lut: lut, components: components!)
    }

    static func number(_ token: String, line: Int) throws -> Double {
        let bytes = Array(token.utf8)
        guard !bytes.isEmpty else { throw SPI1DFailure(.invalidNumber, line: line) }
        let lower = token.lowercased()
        if ["nan", "+nan", "-nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"].contains(lower) {
            throw SPI1DFailure(.nonFiniteValue, line: line)
        }
        var index = 0
        if bytes[index] == 43 || bytes[index] == 45 { index += 1 }
        var digits = 0
        while index < bytes.count && (48...57).contains(bytes[index]) { digits += 1; index += 1 }
        if index < bytes.count && bytes[index] == 46 {
            index += 1
            while index < bytes.count && (48...57).contains(bytes[index]) { digits += 1; index += 1 }
        }
        guard digits > 0 else { throw SPI1DFailure(.invalidNumber, line: line) }
        if index < bytes.count && (bytes[index] == 69 || bytes[index] == 101) {
            index += 1
            if index < bytes.count && (bytes[index] == 43 || bytes[index] == 45) { index += 1 }
            let exponentStart = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > exponentStart else { throw SPI1DFailure(.invalidNumber, line: line) }
        }
        guard index == bytes.count, let value = Double(token) else {
            throw SPI1DFailure(.invalidNumber, line: line)
        }
        guard value.isFinite else { throw SPI1DFailure(.nonFiniteValue, line: line) }
        return value
    }
}

public enum SPI1DWriter {
    public static func header(size: Int, domain: LUTDomain, components: Int) -> String {
        "Version 1\nFrom \(domain.min.r) \(domain.max.r)\nLength \(size)\nComponents \(components)\n{\n"
    }

    public static func row(sample: RGB64, components: Int) -> String {
        switch components {
        case 1: return "\(sample.r)\n"
        case 2: return "\(sample.r) \(sample.g)\n"
        default: return "\(sample.r) \(sample.g) \(sample.b)\n"
        }
    }

    public static func serialize(_ file: SPI1DFile) -> String {
        let lut = file.lut
        var lines = ["Version 1", "From \(lut.domain.min.r) \(lut.domain.max.r)",
                     "Length \(lut.size)", "Components \(file.components)", "{"]
        for sample in lut.samples {
            switch file.components {
            case 1: lines.append("\(sample.r)")
            case 2: lines.append("\(sample.r) \(sample.g)")
            default: lines.append("\(sample.r) \(sample.g) \(sample.b)")
            }
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }
}
