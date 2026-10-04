import Foundation
import LUTCore

public enum CubeDimension: Int, Equatable, Sendable {
    case one = 1
    case three = 3
}

public enum CubeDialect: String, Codable, Sendable {
    case general
    case resolveInputRange
    case domain
}

public enum CubeFailureCategory: String, Equatable, Sendable {
    case rowCountMismatch
    case nonFiniteValue
    case invalidDimension
    case invalidDomain
    case resourceLimit
    case invalidNumber
    case malformedHeader
    case unsupported
    case invalidEncoding
}

public struct CubeFailure: Error, Equatable, Sendable {
    public let category: CubeFailureCategory
    public let line: Int

    public init(_ category: CubeFailureCategory, line: Int) {
        self.category = category
        self.line = line
    }
}

public struct CubeShaper: Equatable, Sendable {
    public let size: Int
    public let domain: LUTDomain
    public let samples: [RGB64]

    public init(size: Int, domain: LUTDomain, samples: [RGB64]) throws {
        let expected = try CubeParser.checkedNodeCount(dimension: .one, size: size, line: 0)
        guard samples.count == expected else { throw CubeFailure(.rowCountMismatch, line: 0) }
        self.size = size
        self.domain = domain
        self.samples = samples
    }
}

public struct CubeLUT: Equatable, Sendable {
    public let dimension: CubeDimension
    public let size: Int
    public let domain: LUTDomain
    public let samples: [RGB64]
    public let title: String?
    public let shaper: CubeShaper?

    public init(dimension: CubeDimension, size: Int, domain: LUTDomain, samples: [RGB64], title: String? = nil,
                shaper: CubeShaper? = nil) throws {
        guard size >= 2 else { throw CubeFailure(.invalidDimension, line: 0) }
        let expected = try CubeParser.checkedNodeCount(dimension: dimension, size: size, line: 0)
        guard samples.count == expected else { throw CubeFailure(.rowCountMismatch, line: 0) }
        if let shaper {
            guard dimension == .three else { throw CubeFailure(.invalidDimension, line: 0) }
            try CubeParser.checkCombinedBytes(one: shaper.size, three: size, line: 0)
        }
        self.dimension = dimension
        self.size = size
        self.domain = domain
        self.samples = samples
        self.title = title
        self.shaper = shaper
    }

    public func sample(_ input: RGB64, interpolation: LUTInterpolation,
                       outside: LUTOutsidePolicy) throws -> RGB64 {
        try preparedSampler(interpolation: interpolation).sample(input, outside: outside)
    }

    /// Prepare once for repeated probes; cubic stores its extended grid here.
    public func preparedSampler(interpolation: LUTInterpolation) throws -> PreparedCubeSampler {
        try PreparedCubeSampler(lut: self, interpolation: interpolation)
    }

    fileprivate func sampleStandard(_ input: RGB64, interpolation: LUTInterpolation,
                                    outside: LUTOutsidePolicy) throws -> RGB64 {
        guard outside != .legacyExtensionV1 else { throw VolumeError.unsupportedOutsidePolicy }
        let shaped: RGB64
        if let shaper {
            shaped = try Self.sample1D(input, domain: shaper.domain, samples: shaper.samples, outside: outside)
        } else {
            shaped = input
        }
        if dimension == .one {
            return try Self.sample1D(shaped, domain: domain, samples: samples, outside: outside)
        }
        return try LUTVolume3D(size: size, domain: domain, samples: samples)
            .sample(shaped, interpolation: interpolation, outside: outside)
    }

    private static func sample1D(_ input: RGB64, domain: LUTDomain, samples: [RGB64],
                                 outside: LUTOutsidePolicy) throws -> RGB64 {
        var result = [Double](repeating: 0, count: 3)
        for channel in 0..<3 {
            let lower = domain.min[channel]
            let upper = domain.max[channel]
            let value = input[channel]
            if outside == .reject && (value < lower || value > upper) {
                throw VolumeError.outsideDomain
            }
            let clamped = min(max(value, lower), upper)
            let position = (clamped - lower) / (upper - lower) * Double(samples.count - 1)
            let index = min(Int(position.rounded(.down)), samples.count - 2)
            let fraction = position - Double(index)
            result[channel] = samples[index][channel] * (1 - fraction) + samples[index + 1][channel] * fraction
        }
        return try RGB64(result[0], result[1], result[2])
    }
}

public enum CubeSamplingError: Error, Equatable, Sendable {
    case unsupportedTricubicLayout
    case resourceLimit
}

public struct PreparedCubeSampler: Sendable {
    private let lut: CubeLUT
    private let interpolation: LUTInterpolation
    private let cubic: LegacyTricubicVolume3D?
    private let curves: [LegacyCubicCurve1D]
    /// Three channel reports for a 1D LUT or combined shaper; empty for other layouts.
    public var cubicEndpointSlopes: [LegacyCubicEndpointSlopes] { curves.map(\.endpointSlopes) }

    fileprivate init(lut: CubeLUT, interpolation: LUTInterpolation) throws {
        if interpolation == .tricubicLegacyV1 {
            let curveCount = lut.dimension == .one ? lut.samples.count : (lut.shaper?.samples.count ?? 0)
            // Combined preparation, including scalar transient slopes, stays within 64 MiB.
            let curveBytes = curveCount * 6 * MemoryLayout<Double>.stride * 3
            let extended = lut.size + 2
            let gridBytes = lut.dimension == .three ? extended * extended * extended * MemoryLayout<RGB64>.stride : 0
            guard curveBytes + gridBytes <= CubeParser.maxDecodedBytes else { throw CubeSamplingError.resourceLimit }
            if lut.dimension == .one {
                cubic = nil
                curves = try Self.prepareCurves(domain: lut.domain, samples: lut.samples)
            } else {
                cubic = try LegacyTricubicVolume3D(size: lut.size, domain: lut.domain, samples: lut.samples)
                if let shaper = lut.shaper {
                    curves = try Self.prepareCurves(domain: shaper.domain, samples: shaper.samples)
                } else { curves = [] }
            }
        } else {
            cubic = nil
            curves = []
        }
        self.lut = lut
        self.interpolation = interpolation
    }

    public func sample(_ input: RGB64, outside: LUTOutsidePolicy) throws -> RGB64 {
        if cubic != nil && outside == .legacyExtensionV1 { throw VolumeError.unsupportedOutsidePolicy }
        var shaped = input
        if !curves.isEmpty {
            shaped = try RGB64(curves[0].sample(input.r, outside: outside),
                               curves[1].sample(input.g, outside: outside),
                               curves[2].sample(input.b, outside: outside))
            if lut.dimension == .one { return shaped }
        }
        if let cubic { return try cubic.sample(shaped, outside: outside) }
        return try lut.sampleStandard(input, interpolation: interpolation, outside: outside)
    }

    private static func prepareCurves(domain: LUTDomain, samples: [RGB64]) throws -> [LegacyCubicCurve1D] {
        try (0..<3).map { channel in
            try LegacyCubicCurve1D(values: samples.map { $0[channel] },
                                   lower: domain.min[channel], upper: domain.max[channel])
        }
    }
}

public enum CubeParser {
    public static let maxFileBytes = 256 * 1024 * 1024
    public static let maxDecodedBytes = 64 * 1024 * 1024
    private static let maxLineBytes = 1024 * 1024

    public static func parse(url: URL) throws -> CubeLUT {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let bytes = attributes[.size] as? NSNumber, bytes.int64Value > maxFileBytes {
            throw CubeFailure(.resourceLimit, line: 0)
        }
        return try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    static func checkedNodeCount(dimension: CubeDimension, size: Int, line: Int) throws -> Int {
        guard size >= 2 else { throw CubeFailure(.invalidDimension, line: line) }
        var count = size
        if dimension == .three {
            let (square, squareOverflow) = size.multipliedReportingOverflow(by: size)
            let (cube, cubeOverflow) = square.multipliedReportingOverflow(by: size)
            guard !squareOverflow, !cubeOverflow else { throw CubeFailure(.resourceLimit, line: line) }
            count = cube
        }
        let (bytes, overflow) = count.multipliedReportingOverflow(by: MemoryLayout<RGB64>.stride)
        guard !overflow, bytes <= maxDecodedBytes else { throw CubeFailure(.resourceLimit, line: line) }
        return count
    }

    static func checkCombinedBytes(one: Int, three: Int, line: Int) throws {
        let oneCount = try checkedNodeCount(dimension: .one, size: one, line: line)
        let threeCount = try checkedNodeCount(dimension: .three, size: three, line: line)
        let (total, overflow) = oneCount.addingReportingOverflow(threeCount)
        guard !overflow, total <= maxDecodedBytes / MemoryLayout<RGB64>.stride else {
            throw CubeFailure(.resourceLimit, line: line)
        }
    }

    public static func parse(_ data: Data) throws -> CubeLUT {
        guard data.count <= maxFileBytes else { throw CubeFailure(.resourceLimit, line: 0) }
        var oneSize: Int?
        var threeSize: Int?
        var expectedRows = 0
        var title: String?
        var domainMin: RGB64?
        var domainMax: RGB64?
        var oneRange: (Double, Double)?
        var threeRange: (Double, Double)?
        var samples: [RGB64] = []
        var rowsStarted = false
        var lineNumber = 0
        var lineBytes: [UInt8] = []

        func processLine() throws {
            lineNumber += 1
            if lineBytes.last == 13 { lineBytes.removeLast() }
            guard let source = String(bytes: lineBytes, encoding: .utf8) else {
                throw CubeFailure(.invalidEncoding, line: lineNumber)
            }
            lineBytes.removeAll(keepingCapacity: true)
            let trimmed = source.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return }
            let effective = trimmed.hasPrefix("TITLE ") ? trimmed : String(trimmed.prefix(while: { $0 != "#" })).trimmingCharacters(in: .whitespaces)
            if effective.isEmpty { return }
            let tokens = effective.split(whereSeparator: \.isWhitespace).map(String.init)
            let head = tokens[0]

            if head == "TITLE" {
                guard !rowsStarted, title == nil else { throw CubeFailure(.malformedHeader, line: lineNumber) }
                let content = effective.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard content.count >= 2, content.first == "\"", content.last == "\"" else {
                    throw CubeFailure(.malformedHeader, line: lineNumber)
                }
                let body = content.dropFirst().dropLast()
                guard !body.contains("\"") else { throw CubeFailure(.malformedHeader, line: lineNumber) }
                title = String(body)
                return
            }
            if head == "LUT_1D_SIZE" || head == "LUT_3D_SIZE" {
                guard !rowsStarted, tokens.count == 2, let parsedSize = Int(tokens[1]) else {
                    throw CubeFailure(.invalidDimension, line: lineNumber)
                }
                let parsedDimension: CubeDimension = head == "LUT_1D_SIZE" ? .one : .three
                let count = try checkedNodeCount(dimension: parsedDimension, size: parsedSize, line: lineNumber)
                if parsedDimension == .one {
                    guard oneSize == nil else { throw CubeFailure(.invalidDimension, line: lineNumber) }
                    oneSize = parsedSize
                } else {
                    guard threeSize == nil else { throw CubeFailure(.invalidDimension, line: lineNumber) }
                    threeSize = parsedSize
                }
                if let oneSize, let threeSize {
                    try checkCombinedBytes(one: oneSize, three: threeSize, line: lineNumber)
                }
                let (total, overflow) = expectedRows.addingReportingOverflow(count)
                guard !overflow else { throw CubeFailure(.resourceLimit, line: lineNumber) }
                expectedRows = total
                samples.reserveCapacity(expectedRows)
                return
            }
            if head == "DOMAIN_MIN" || head == "DOMAIN_MAX" {
                guard !rowsStarted, tokens.count == 4, oneRange == nil, threeRange == nil else {
                    throw CubeFailure(.invalidDomain, line: lineNumber)
                }
                let value = try RGB64(
                    decimal(tokens[1], line: lineNumber),
                    decimal(tokens[2], line: lineNumber),
                    decimal(tokens[3], line: lineNumber)
                )
                if head == "DOMAIN_MIN" {
                    guard domainMin == nil else { throw CubeFailure(.invalidDomain, line: lineNumber) }
                    domainMin = value
                } else {
                    guard domainMax == nil else { throw CubeFailure(.invalidDomain, line: lineNumber) }
                    domainMax = value
                }
                return
            }
            if head == "LUT_1D_INPUT_RANGE" || head == "LUT_3D_INPUT_RANGE" {
                guard !rowsStarted, tokens.count == 3, domainMin == nil, domainMax == nil else {
                    throw CubeFailure(.invalidDomain, line: lineNumber)
                }
                let lower = try decimal(tokens[1], line: lineNumber)
                let upper = try decimal(tokens[2], line: lineNumber)
                guard lower < upper else { throw CubeFailure(.invalidDomain, line: lineNumber) }
                if head == "LUT_1D_INPUT_RANGE" {
                    guard oneSize != nil, oneRange == nil else { throw CubeFailure(.invalidDomain, line: lineNumber) }
                    oneRange = (lower, upper)
                } else {
                    guard threeSize != nil, threeRange == nil else { throw CubeFailure(.invalidDomain, line: lineNumber) }
                    threeRange = (lower, upper)
                }
                return
            }
            guard expectedRows > 0 else {
                throw CubeFailure(.malformedHeader, line: lineNumber)
            }
            rowsStarted = true
            if isNonFiniteToken(head) {
                throw CubeFailure(.nonFiniteValue, line: lineNumber)
            }
            guard head.first?.isNumber == true || head.first == "-" || head.first == "+" || head.first == "." else {
                throw CubeFailure(.unsupported, line: lineNumber)
            }
            guard tokens.count == 3 else { throw CubeFailure(.invalidNumber, line: lineNumber) }
            let sample = try RGB64(
                decimal(tokens[0], line: lineNumber),
                decimal(tokens[1], line: lineNumber),
                decimal(tokens[2], line: lineNumber)
            )
            guard samples.count < expectedRows else { throw CubeFailure(.rowCountMismatch, line: lineNumber) }
            samples.append(sample)
        }

        for byte in data {
            if byte == 10 {
                try processLine()
            } else {
                guard lineBytes.count < maxLineBytes else { throw CubeFailure(.resourceLimit, line: lineNumber + 1) }
                lineBytes.append(byte)
            }
        }
        if !lineBytes.isEmpty { try processLine() }
        guard oneSize != nil || threeSize != nil else {
            throw CubeFailure(.invalidDimension, line: lineNumber)
        }
        guard samples.count == expectedRows else { throw CubeFailure(.rowCountMismatch, line: lineNumber) }
        if oneSize != nil && threeSize != nil && (domainMin != nil || domainMax != nil) {
            throw CubeFailure(.invalidDomain, line: lineNumber)
        }
        func resolvedDomain(_ range: (Double, Double)?) throws -> LUTDomain {
            do {
                if let range {
                    return try LUTDomain(min: RGB64(range.0, range.0, range.0),
                                         max: RGB64(range.1, range.1, range.1))
                }
                if domainMin == nil && domainMax == nil { return .unit }
                if let domainMin, let domainMax { return try LUTDomain(min: domainMin, max: domainMax) }
            } catch {}
            throw CubeFailure(.invalidDomain, line: lineNumber)
        }
        if let threeSize {
            let shaper: CubeShaper?
            let volumeSamples: [RGB64]
            if let oneSize {
                shaper = try CubeShaper(size: oneSize, domain: resolvedDomain(oneRange),
                                        samples: Array(samples.prefix(oneSize)))
                volumeSamples = Array(samples.dropFirst(oneSize))
            } else {
                shaper = nil
                volumeSamples = samples
            }
            return try CubeLUT(dimension: .three, size: threeSize, domain: resolvedDomain(threeRange),
                               samples: volumeSamples, title: title, shaper: shaper)
        }
        return try CubeLUT(dimension: .one, size: oneSize!, domain: resolvedDomain(oneRange),
                           samples: samples, title: title)
    }

    private static func decimal(_ token: String, line: Int) throws -> Double {
        if isNonFiniteToken(token) {
            throw CubeFailure(.nonFiniteValue, line: line)
        }
        let bytes = Array(token.utf8)
        guard !bytes.isEmpty else { throw CubeFailure(.invalidNumber, line: line) }
        var index = 0
        if bytes[index] == 43 || bytes[index] == 45 { index += 1 }
        var digits = 0
        while index < bytes.count && (48...57).contains(bytes[index]) { digits += 1; index += 1 }
        if index < bytes.count && bytes[index] == 46 {
            index += 1
            while index < bytes.count && (48...57).contains(bytes[index]) { digits += 1; index += 1 }
        }
        guard digits > 0 else { throw CubeFailure(.invalidNumber, line: line) }
        if index < bytes.count && (bytes[index] == 69 || bytes[index] == 101) {
            index += 1
            if index < bytes.count && (bytes[index] == 43 || bytes[index] == 45) { index += 1 }
            let exponentStart = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > exponentStart else { throw CubeFailure(.invalidNumber, line: line) }
        }
        guard index == bytes.count, let value = Double(token) else { throw CubeFailure(.invalidNumber, line: line) }
        guard value.isFinite else { throw CubeFailure(.nonFiniteValue, line: line) }
        return value
    }

    private static func isNonFiniteToken(_ token: String) -> Bool {
        ["nan", "+nan", "-nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"]
            .contains(token.lowercased())
    }
}

public enum CubeWriter {
    public static func serialize(_ lut: CubeLUT, dialect: CubeDialect = .domain) throws -> String {
        if let shaper = lut.shaper {
            let shaperHeader = try header(dimension: .one, size: shaper.size, domain: shaper.domain,
                                          title: lut.title, dialect: dialect)
            let volumeHeader = try header(dimension: .three, size: lut.size, domain: lut.domain,
                                          title: nil, dialect: dialect)
            guard dialect == .resolveInputRange || (shaper.domain == .unit && lut.domain == .unit) else {
                throw CubeFailure(.unsupported, line: 0)
            }
            var lines = [shaperHeader, volumeHeader]
            for sample in shaper.samples { lines.append(sampleLine(sample)) }
            for sample in lut.samples { lines.append(sampleLine(sample)) }
            return lines.joined()
        }
        var lines = [try header(dimension: lut.dimension, size: lut.size, domain: lut.domain, title: lut.title, dialect: dialect)]
        for sample in lut.samples {
            lines.append(sampleLine(sample))
        }
        return lines.joined(separator: "")
    }

    public static func header(dimension: CubeDimension, size: Int, domain: LUTDomain, title: String?,
                              dialect: CubeDialect = .domain) throws -> String {
        var lines: [String] = []
        if let title {
            guard !title.contains("\"") && !title.contains("\n") && !title.contains("\r") else {
                throw CubeFailure(.malformedHeader, line: 0)
            }
            lines.append("TITLE \"\(title)\"")
        }
        lines.append(dimension == .one ? "LUT_1D_SIZE \(size)" : "LUT_3D_SIZE \(size)")
        if domain != .unit {
            switch dialect {
            case .general:
                throw CubeFailure(.unsupported, line: 0)
            case .resolveInputRange:
                guard domain.min.r == domain.min.g, domain.min.r == domain.min.b,
                      domain.max.r == domain.max.g, domain.max.r == domain.max.b else {
                    throw CubeFailure(.unsupported, line: 0)
                }
                let directive = dimension == .one ? "LUT_1D_INPUT_RANGE" : "LUT_3D_INPUT_RANGE"
                lines.append("\(directive) \(number(domain.min.r)) \(number(domain.max.r))")
            case .domain:
                lines.append("DOMAIN_MIN \(number(domain.min.r)) \(number(domain.min.g)) \(number(domain.min.b))")
                lines.append("DOMAIN_MAX \(number(domain.max.r)) \(number(domain.max.g)) \(number(domain.max.b))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func sampleLine(_ sample: RGB64) -> String {
        "\(number(sample.r)) \(number(sample.g)) \(number(sample.b))\n"
    }

    private static func number(_ value: Double) -> String {
        value == 0 ? "0" : String(value)
    }
}
