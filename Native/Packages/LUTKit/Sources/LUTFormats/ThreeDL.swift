import Foundation
import LUTCore

public enum ThreeDLFlavor: String, Codable, Sendable {
    public static let batchAlgorithm = "native.3dl-batch-flavor.v1"
    case flame
    case lustre
    case kodak
}

public enum ThreeDLFailureCategory: String, Equatable, Sendable {
    case malformedHeader
    case unsupported
    case invalidDimension
    case invalidNumber
    case nonFiniteValue
    case invalidCodeValue
    case unsupportedShaper
    case rowCountMismatch
    case lossyRepresentation
    case resourceLimit
    case invalidEncoding
}

public struct ThreeDLFailure: Error, Equatable, Sendable {
    public let category: ThreeDLFailureCategory
    public let line: Int

    public init(_ category: ThreeDLFailureCategory, line: Int = 0) {
        self.category = category
        self.line = line
    }
}

public enum ThreeDLParser {
    public static let maxFileBytes = CubeParser.maxFileBytes
    private static let maxLineBytes = 1024 * 1024

    /// Selects the strict Lustre grammar when its explicit mesh marker is
    /// present. Plain 3DL streams are intentionally parsed as the shared
    /// Flame/Kodak row grammar because those two legacy layouts are bytewise
    /// indistinguishable without vendor metadata.
    public static func parseAuto(_ data: Data) throws -> CubeLUT {
        let prefix = String(decoding: data.prefix(64 * 1024), as: UTF8.self).lowercased()
        if prefix.split(whereSeparator: { $0.isWhitespace || $0 == "\r" || $0 == "\n" })
            .contains("3dmesh") {
            return try parse(data, flavor: .lustre)
        }
        return try parse(data, flavor: .flame)
    }

    public static func parse(_ data: Data, flavor: ThreeDLFlavor) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw ThreeDLFailure(.resourceLimit) }
        guard flavor == .flame || flavor == .lustre || flavor == .kodak else {
            throw ThreeDLFailure(.unsupported)
        }

        var lineBytes: [UInt8] = []
        var lineNumber = 0
        var nodeCount: Int?
        var declaredRows: Int?
        var inputBits: Int?
        var outputBits: Int?
        var title: String?
        var shaper: [Int]?
        var rows: [RGB64] = []
        var sawMesh = false
        var meshExponent: Int?
        var meshOutputBits: Int?
        var sawLUT8 = false
        var sawGammaOne = false

        func integerMetadata(_ text: String, key: String) -> Int? {
            let lower = text.lowercased()
            guard let range = lower.range(of: key) else { return nil }
            return Int(lower[range.upperBound...].trimmingCharacters(in: .whitespaces))
        }

        func parseFiniteInteger(_ token: Substring) throws -> Int {
            guard token.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "+" }),
                  let value = Int(token) else {
                if let value = Double(token), !value.isFinite { throw ThreeDLFailure(.nonFiniteValue, line: lineNumber) }
                throw ThreeDLFailure(.invalidNumber, line: lineNumber)
            }
            return value
        }

        func parseLine(_ raw: [UInt8]) throws {
            lineNumber += 1
            var bytes = raw
            if bytes.last == 13 { bytes.removeLast() }
            guard let source = String(bytes: bytes, encoding: .utf8) else {
                throw ThreeDLFailure(.invalidEncoding, line: lineNumber)
            }
            let trimmed = source.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return }
            if trimmed.hasPrefix("#") {
                let metadata = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let lower = metadata.lowercased()
                if lower.hasPrefix("number of nodes:"), let value = integerMetadata(metadata, key: "number of nodes:") {
                    guard shaper == nil else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
                    guard value >= 2 else { throw ThreeDLFailure(.invalidDimension, line: lineNumber) }
                    guard nodeCount == nil || nodeCount == value else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
                    do { _ = try CubeParser.checkedNodeCount(dimension: .three, size: value, line: lineNumber) }
                    catch { throw ThreeDLFailure(.resourceLimit, line: lineNumber) }
                    nodeCount = value
                } else if lower.hasPrefix("number of rows:"), let value = integerMetadata(metadata, key: "number of rows:") {
                    guard shaper == nil, declaredRows == nil || declaredRows == value else {
                        throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                    }
                    declaredRows = value
                } else if lower.hasPrefix("input range:"), let value = integerMetadata(metadata, key: "input range:") {
                    guard shaper == nil, inputBits == nil || inputBits == value else {
                        throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                    }
                    guard (1...24).contains(value) else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
                    inputBits = value
                } else if lower.hasPrefix("output range:"), let value = integerMetadata(metadata, key: "output range:") {
                    guard shaper == nil, outputBits == nil || outputBits == value else {
                        throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                    }
                    guard (1...24).contains(value) else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
                    outputBits = value
                } else if lower.hasPrefix("title :") || lower.hasPrefix("title:") {
                    let colon = metadata.firstIndex(of: ":")!
                    title = String(metadata[metadata.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                } else if lower.hasPrefix("number of nodes:") || lower.hasPrefix("number of rows:") ||
                            lower.hasPrefix("input range:") || lower.hasPrefix("output range:") {
                    throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                }
                return
            }
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed == "3dmesh" {
                guard flavor == .lustre, !sawMesh, shaper == nil else {
                    throw ThreeDLFailure(.unsupported, line: lineNumber)
                }
                sawMesh = true
                return
            }
            if lowerTrimmed.hasPrefix("mesh") {
                guard flavor == .lustre, sawMesh, shaper == nil else {
                    throw ThreeDLFailure(.unsupported, line: lineNumber)
                }
                let fields = trimmed.split(whereSeparator: { $0.isWhitespace })
                guard fields.count == 3, let exponent = Int(fields[1]), let bits = Int(fields[2]),
                      (1...7).contains(exponent), (1...24).contains(bits),
                      meshExponent == nil, meshOutputBits == nil else {
                    throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                }
                meshExponent = exponent
                meshOutputBits = bits
                return
            }
            if lowerTrimmed == "lut8" {
                guard flavor == .lustre, shaper != nil else {
                    throw ThreeDLFailure(.unsupported, line: lineNumber)
                }
                sawLUT8 = true
                return
            }
            if lowerTrimmed == "gamma 1.0" {
                guard flavor == .lustre, sawLUT8 else {
                    throw ThreeDLFailure(.unsupported, line: lineNumber)
                }
                sawGammaOne = true
                return
            }
            if lowerTrimmed.hasPrefix("gamma") || lowerTrimmed.hasPrefix("lut8") {
                throw ThreeDLFailure(.unsupported, line: lineNumber)
            }
            let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard !tokens.isEmpty else { return }
            if shaper == nil {
                guard nodeCount != nil, inputBits != nil, outputBits != nil else {
                    throw ThreeDLFailure(.malformedHeader, line: lineNumber)
                }
                guard tokens.count >= 2 else { throw ThreeDLFailure(.invalidDimension, line: lineNumber) }
                shaper = try tokens.map(parseFiniteInteger)
                return
            }
            guard tokens.count == 3 else { throw ThreeDLFailure(.invalidNumber, line: lineNumber) }
            let codes = try tokens.map(parseFiniteInteger)
            guard let bits = outputBits else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
            let maxCode = (1 << bits) - 1
            guard codes.allSatisfy({ (0...maxCode).contains($0) }) else {
                throw ThreeDLFailure(.invalidCodeValue, line: lineNumber)
            }
            let normalized = codes.map { Double($0) / Double(maxCode) }
            rows.append(try RGB64(normalized[0], normalized[1], normalized[2]))
            if let nodes = nodeCount, rows.count > nodes * nodes * nodes {
                throw ThreeDLFailure(.rowCountMismatch, line: lineNumber)
            }
        }

        for byte in data {
            if byte == 10 {
                try parseLine(lineBytes)
                lineBytes.removeAll(keepingCapacity: true)
            } else {
                guard lineBytes.count < maxLineBytes else { throw ThreeDLFailure(.resourceLimit, line: lineNumber + 1) }
                lineBytes.append(byte)
            }
        }
        if !lineBytes.isEmpty { try parseLine(lineBytes) }

        guard let nodes = nodeCount, let inBits = inputBits, let declaredOutputBits = outputBits,
              let shape = shaper else { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
        switch flavor {
        case .flame, .kodak:
            guard !sawMesh, meshExponent == nil, meshOutputBits == nil,
                  !sawLUT8, !sawGammaOne else {
                throw ThreeDLFailure(.unsupported, line: lineNumber)
            }
        case .lustre:
            guard sawMesh, let exponent = meshExponent, let meshBits = meshOutputBits,
                  sawLUT8, sawGammaOne, nodes == (1 << exponent) + 1,
                  meshBits == declaredOutputBits else {
                throw ThreeDLFailure(.malformedHeader, line: lineNumber)
            }
        }
        guard shape.count == nodes else { throw ThreeDLFailure(.unsupportedShaper, line: lineNumber) }
        guard shape.allSatisfy({ (0...(1 << inBits) - 1).contains($0) }) else {
            throw ThreeDLFailure(.invalidCodeValue, line: lineNumber)
        }
        let maxInput = (1 << inBits) - 1
        guard shape.first == 0, shape.last == maxInput else {
            throw ThreeDLFailure(.unsupportedShaper, line: lineNumber)
        }
        for pair in zip(shape, shape.dropFirst()) {
            guard pair.0 <= pair.1 else { throw ThreeDLFailure(.unsupportedShaper, line: lineNumber) }
        }
        let expectedRows = nodes * nodes * nodes
        if let declaredRows, declaredRows != expectedRows { throw ThreeDLFailure(.malformedHeader, line: lineNumber) }
        guard rows.count == expectedRows else { throw ThreeDLFailure(.rowCountMismatch, line: lineNumber) }
        // The Flame text stream is R-major/G-middle/B-minor. Convert it to the
        // shared R-fast nodeIndex(r,g,b) layout used by LUTCore.
        var samples = Array(repeating: try RGB64(0, 0, 0), count: expectedRows)
        for fileIndex in 0..<expectedRows {
            let red = fileIndex / (nodes * nodes)
            let green = (fileIndex / nodes) % nodes
            let blue = fileIndex % nodes
            samples[red + nodes * (green + nodes * blue)] = rows[fileIndex]
        }
        let identityShape = shape.enumerated().allSatisfy { index, value in
            value == Int(ceil(Double(maxInput) * Double(index) / Double(shape.count - 1)))
        }
        let cubeShaper: CubeShaper?
        if identityShape {
            cubeShaper = nil
        } else {
            let normalizedShaper = shape.map { value -> RGB64 in
                let normalized = Double(value) / Double(maxInput)
                return try! RGB64(normalized, normalized, normalized)
            }
            cubeShaper = try CubeShaper(size: nodes, domain: .unit, samples: normalizedShaper)
        }
        return try CubeLUT(dimension: .three, size: nodes, domain: .unit,
                           samples: samples, title: title, shaper: cubeShaper)
    }
}

public enum ThreeDLWriter {
    public static func header(size: Int, inputBits: Int, outputBits: Int, title: String?,
                              flavor: ThreeDLFlavor = .flame,
                              shaper: CubeShaper? = nil) throws -> String {
        guard size >= 2, (1...24).contains(inputBits), (1...24).contains(outputBits),
              (try? CubeParser.checkedNodeCount(dimension: .three, size: size, line: 0)) != nil else {
            throw ThreeDLFailure(.malformedHeader)
        }
        if let title, title.contains("\n") || title.contains("\r") {
            throw ThreeDLFailure(.lossyRepresentation)
        }
        let inputMax = (1 << inputBits) - 1
        var text = "# NUMBER OF COLUMNS: 3\n# NUMBER OF ROWS: \(size * size * size)\n"
        text += "# NUMBER OF NODES: \(size)\n# INPUT RANGE: \(inputBits)\n# OUTPUT RANGE: \(outputBits)\n"
        if let title { text += "# TITLE : \(title)\n" }
        if flavor == .lustre {
            guard let exponent = (3...7).first(where: { (1 << $0) + 1 == size }) else {
                throw ThreeDLFailure(.invalidDimension)
            }
            text += "3DMESH\nMesh \(exponent) \(outputBits)\n"
        }
        let shapeCodes: [Int]
        if let shaper {
            guard shaper.size == size,
                  shaper.domain == .unit,
                  shaper.samples.count == size else {
                throw ThreeDLFailure(.lossyRepresentation)
            }
            shapeCodes = try shaper.samples.map { sample in
                guard sample.r.isFinite, sample.g.isFinite, sample.b.isFinite,
                      sample.r == sample.g, sample.r == sample.b,
                      (0...1).contains(sample.r) else {
                    throw ThreeDLFailure(.lossyRepresentation)
                }
                let code = Int((sample.r * Double(inputMax)).rounded(.toNearestOrAwayFromZero))
                guard (0...inputMax).contains(code),
                      abs(Double(code) / Double(inputMax) - sample.r) <= 2e-12 else {
                    throw ThreeDLFailure(.lossyRepresentation)
                }
                return code
            }
            guard shapeCodes.first == 0, shapeCodes.last == inputMax,
                  zip(shapeCodes, shapeCodes.dropFirst()).allSatisfy({ $0.0 <= $0.1 }) else {
                throw ThreeDLFailure(.lossyRepresentation)
            }
        } else {
            shapeCodes = (0..<size).map {
                Int(ceil(Double(inputMax) * Double($0) / Double(size - 1)))
            }
        }
        return text + shapeCodes.map(String.init).joined(separator: " ") + "\n"
    }

    public static func fixedWidthRow(_ sample: RGB64, outputBits: Int) throws -> String {
        guard (1...24).contains(outputBits) else { throw ThreeDLFailure(.malformedHeader) }
        let maxCode = (1 << outputBits) - 1
        let width = String(maxCode).count
        let codes = try (0..<3).map { channel -> String in
            let value = sample[channel]
            guard value.isFinite, value >= 0, value <= 1 else {
                throw ThreeDLFailure(.lossyRepresentation)
            }
            let code = String(Int((value * Double(maxCode)).rounded(.toNearestOrAwayFromZero)))
            return String(repeating: "0", count: width - code.count) + code
        }
        return codes.joined(separator: " ") + "\n"
    }

    public static func serialize(_ lut: CubeLUT, inputBits: Int, outputBits: Int,
                                 flavor: ThreeDLFlavor) throws -> String {
        guard flavor == .flame || flavor == .lustre || flavor == .kodak else {
            throw ThreeDLFailure(.unsupported)
        }
        guard lut.dimension == .three,
              lut.domain.min.r.bitPattern == 0, lut.domain.min.g.bitPattern == 0, lut.domain.min.b.bitPattern == 0,
              lut.domain.max.r.bitPattern == 1.0.bitPattern,
              lut.domain.max.g.bitPattern == 1.0.bitPattern,
              lut.domain.max.b.bitPattern == 1.0.bitPattern else {
            throw ThreeDLFailure(.lossyRepresentation)
        }
        guard (1...24).contains(inputBits), (1...24).contains(outputBits) else {
            throw ThreeDLFailure(.malformedHeader)
        }
        let outputMax = (1 << outputBits) - 1
        var text = try header(size: lut.size, inputBits: inputBits,
                              outputBits: outputBits, title: lut.title, flavor: flavor,
                              shaper: lut.shaper)
        for red in 0..<lut.size {
            for green in 0..<lut.size {
                for blue in 0..<lut.size {
                    let sample = lut.samples[red + lut.size * (green + lut.size * blue)]
                    var codes: [String] = []
                    for channel in 0..<3 {
                        let value = sample[channel]
                        guard value.isFinite, value >= 0, value <= 1 else {
                            throw ThreeDLFailure(.lossyRepresentation)
                        }
                        let code = Int((value * Double(outputMax)).rounded(.toNearestOrAwayFromZero))
                        codes.append(String(code))
                    }
                    text += codes.joined(separator: " ") + "\n"
                }
            }
        }
        if flavor == .lustre { text += "LUT8\ngamma 1.0\n" }
        return text
    }
}
