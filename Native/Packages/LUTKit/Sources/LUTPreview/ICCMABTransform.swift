import Foundation
import LUTCore

/// ICC v4 `mAB`/`mBA` pipeline for a user supplied profile.
///
/// It decodes only the sections present in the tag and keeps no profile
/// payload after init. Device-side curves and CLUTs may use the full ICC
/// channel range; the optional matrix remains the fixed 3x4 PCS boundary.
public enum ICCMABError: Error, Equatable, Sendable {
    case invalidTag
    case unsupportedChannels
    case malformedSection
    case unsupportedCurve
    case unsupportedCLUT
    case nonFiniteInput
    case nonFiniteResult
    case outsideDomain
}

public struct ICCMABTransform: Sendable {
    private enum Direction { case aToB, bToA }
    private struct Curve: Sendable {
        enum Body: Sendable { case identity, gamma(Double), table([Double]), parametric(Int, [Double]) }
        let body: Body
        func apply(_ value: Double) -> Double {
            switch body {
            case .identity: return value
            case let .gamma(g): return value >= 0 ? pow(value, g) : -pow(-value, g)
            case let .table(values):
                guard values.count > 1 else { return values.first ?? value }
                let x = min(max(value, 0), 1) * Double(values.count - 1)
                let low = Int(floor(x)); let high = min(low + 1, values.count - 1)
                let f = x - Double(low)
                return values[low] + (values[high] - values[low]) * f
            case let .parametric(type, p):
                let x = value
                switch type {
                case 0: return x >= 0 ? pow(x, p[0]) : -pow(-x, p[0])
                case 1:
                    let threshold = -p[2] / p[1]
                    return x >= threshold ? pow(p[1] * x + p[2], p[0]) : 0
                case 2:
                    let threshold = -p[2] / p[1]
                    return x >= threshold ? pow(p[1] * x + p[2], p[0]) + p[3] : p[3]
                case 3:
                    return x >= p[4] ? pow(p[1] * x + p[2], p[0]) + p[3] : p[5] * x
                case 4:
                    return x >= p[4] ? pow(p[1] * x + p[2], p[0]) + p[5] : p[3] * x + p[6]
                default: return x
                }
            }
        }
    }
    private struct CLUT: Sendable {
        let grid: [Int]
        let outputChannels: Int
        let bytesPerSample: Int
        let values: [Double]
        func sample(_ input: [Double], channel: Int) -> Double {
            precondition(input.count == grid.count)
            let position = zip(input, grid).map { min(max($0.0, 0), 1) * Double($0.1 - 1) }
            let low = position.map { Int(floor($0)) }
            let high = zip(low, grid).map { min($0.0 + 1, $0.1 - 1) }
            let fraction = zip(position, low).map { $0.0 - Double($0.1) }
            var result = 0.0
            let cornerCount = 1 << input.count
            for mask in 0..<cornerCount {
                var index = 0; var weight = 1.0
                for axis in 0..<input.count {
                    let upper = (mask & (1 << axis)) != 0
                    let coordinate = upper ? high[axis] : low[axis]
                    weight *= upper ? fraction[axis] : 1 - fraction[axis]
                    index = index * grid[axis] + coordinate
                }
                result += values[index * outputChannels + channel] * weight
            }
            return result
        }
    }

    private let direction: Direction
    private let inputCurves: [Curve]
    private let middleCurves: [Curve]
    private let outputCurves: [Curve]
    private let matrix: [Double]?
    private let offset: [Double]?
    private let clut: CLUT?

    public let inputChannels: Int
    public let outputChannels: Int

    /// Bytes per CLUT sample when the tag carries a CLUT. A missing CLUT is
    /// represented by nil and does not alter the enclosing PCS encoding.
    public var clutBytesPerSample: Int? { clut?.bytesPerSample }

    public init(profileData: Data, tag: String) throws {
        guard tag.utf8.count == 4 else { throw ICCMABError.invalidTag }
        _ = try ICCProfileValidator.validate(profileData)
        let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
        let bytes = [UInt8](payload)
        guard bytes.count >= 32 else { throw ICCMABError.malformedSection }
        let type = String(bytes: bytes[0..<4], encoding: .ascii) ?? ""
        guard type == "mAB " || type == "mBA " else { throw ICCMABError.invalidTag }
        let input = Int(bytes[8]), output = Int(bytes[9])
        guard (1...15).contains(input), (1...15).contains(output) else {
            throw ICCMABError.unsupportedChannels
        }
        let offsets = try stride(from: 12, through: 28, by: 4).map { try Self.u32(bytes, $0) }
        for value in offsets where value != 0 {
            guard value >= 32, value < bytes.count else { throw ICCMABError.malformedSection }
        }
        let present = offsets.filter { $0 != 0 }
        guard !present.isEmpty, present.allSatisfy({ $0 % 4 == 0 }),
              (offsets[1] == 0 || present.filter { $0 == offsets[1] }.count == 1),
              (offsets[3] == 0 || present.filter { $0 == offsets[3] }.count == 1) else {
            throw ICCMABError.malformedSection
        }
        direction = type == "mAB " ? .aToB : .bToA
        let offsetB = offsets[0], offsetMatrix = offsets[1], offsetM = offsets[2], offsetCLUT = offsets[3], offsetA = offsets[4]
        guard offsetB != 0, (offsetA != 0) == (offsetCLUT != 0),
              (offsetM != 0) == (offsetMatrix != 0) else {
            throw ICCMABError.malformedSection
        }
        inputChannels = input
        outputChannels = output
        let inputCurveCount = direction == .aToB ? input : input
        let middleCurveCount = direction == .aToB ? output : input
        let outputCurveCount = direction == .aToB ? output : output
        if direction == .aToB {
            inputCurves = try offsetA == 0 ? Self.identityCurves(inputCurveCount) : Self.readCurves(bytes, at: offsetA, count: inputCurveCount, limit: Self.sectionLimit(offsetA, offsets: offsets, end: bytes.count))
            middleCurves = try offsetM == 0 ? Self.identityCurves(middleCurveCount) : Self.readCurves(bytes, at: offsetM, count: middleCurveCount, limit: Self.sectionLimit(offsetM, offsets: offsets, end: bytes.count))
            outputCurves = try offsetB == 0 ? Self.identityCurves(outputCurveCount) : Self.readCurves(bytes, at: offsetB, count: outputCurveCount, limit: Self.sectionLimit(offsetB, offsets: offsets, end: bytes.count))
        } else {
            inputCurves = try offsetB == 0 ? Self.identityCurves(inputCurveCount) : Self.readCurves(bytes, at: offsetB, count: inputCurveCount, limit: Self.sectionLimit(offsetB, offsets: offsets, end: bytes.count))
            middleCurves = try offsetM == 0 ? Self.identityCurves(middleCurveCount) : Self.readCurves(bytes, at: offsetM, count: middleCurveCount, limit: Self.sectionLimit(offsetM, offsets: offsets, end: bytes.count))
            outputCurves = try offsetA == 0 ? Self.identityCurves(outputCurveCount) : Self.readCurves(bytes, at: offsetA, count: outputCurveCount, limit: Self.sectionLimit(offsetA, offsets: offsets, end: bytes.count))
        }
        if offsetCLUT == 0 { clut = nil } else {
            clut = try Self.readCLUT(bytes, at: offsetCLUT, inputChannels: input,
                                     outputChannels: output,
                                     limit: Self.sectionLimit(offsetCLUT, offsets: offsets, end: bytes.count))
        }
        if offsetMatrix == 0 { matrix = nil; offset = nil } else {
            guard (direction == .aToB ? output == 3 : input == 3) else {
                throw ICCMABError.unsupportedChannels
            }
            guard offsetMatrix + 48 <= Self.sectionLimit(offsetMatrix, offsets: offsets, end: bytes.count) else { throw ICCMABError.malformedSection }
            let entries = try stride(from: offsetMatrix, to: offsetMatrix + 48, by: 4).map {
                Double(try Self.i32(bytes, $0)) / 65536.0
            }
            // ICC stores the 3x3 matrix as nine consecutive s15Fixed16
            // values, followed by the three offset values. The offsets are
            // not interleaved with the matrix rows.
            matrix = Array(entries.prefix(9))
            offset = Array(entries.suffix(3))
        }
    }

    public func sample(_ input: RGB64) throws -> RGB64 {
        guard inputChannels == 3, outputChannels == 3 else { throw ICCMABError.unsupportedChannels }
        let values = try sample([input.r, input.g, input.b])
        return try RGB64(values[0], values[1], values[2])
    }

    /// Executes the complete pipeline using the profile-declared dimensions.
    public func sample(_ input: [Double]) throws -> [Double] {
        guard input.count == inputChannels else { throw ICCMABError.outsideDomain }
        guard input.allSatisfy(\.isFinite) else { throw ICCMABError.nonFiniteInput }
        guard input.allSatisfy({ (0...1).contains($0) }) else { throw ICCMABError.outsideDomain }
        var values = input
        values = inputCurves.enumerated().map { $0.element.apply(values[$0.offset]) }
        guard values.allSatisfy(\.isFinite) else { throw ICCMABError.nonFiniteResult }
        if direction == .aToB {
            if let clut { values = (0..<outputChannels).map { clut.sample(values, channel: $0) } }
            values = middleCurves.enumerated().map { $0.element.apply(values[$0.offset]) }
            guard values.allSatisfy(\.isFinite) else { throw ICCMABError.nonFiniteResult }
            if let matrix {
                guard values.count == 3 else { throw ICCMABError.unsupportedChannels }
                values = Self.apply(matrix, offset: offset!, values: values).map { min(max($0, 0), 1) }
            }
        } else {
            if let matrix {
                guard values.count == 3 else { throw ICCMABError.unsupportedChannels }
                values = Self.apply(matrix, offset: offset!, values: values).map { min(max($0, 0), 1) }
            }
            values = middleCurves.enumerated().map { $0.element.apply(values[$0.offset]) }
            guard values.allSatisfy(\.isFinite) else { throw ICCMABError.nonFiniteResult }
            if let clut { values = (0..<outputChannels).map { clut.sample(values, channel: $0) } }
        }
        values = outputCurves.enumerated().map { $0.element.apply(values[$0.offset]) }
        guard values.allSatisfy(\.isFinite) else { throw ICCMABError.nonFiniteResult }
        return values
    }

    private static func apply(_ matrix: [Double], offset: [Double], values: [Double]) -> [Double] {
        [0, 1, 2].map { row in offset[row] + (0..<3).reduce(0) { $0 + matrix[row * 3 + $1] * values[$1] } }
    }
    private static func identityCurves(_ count: Int) throws -> [Curve] { Array(repeating: Curve(body: .identity), count: count) }
    private static func u16(_ b: [UInt8], _ o: Int) throws -> Int { guard o >= 0, o + 2 <= b.count else { throw ICCMABError.malformedSection }; return Int(b[o]) << 8 | Int(b[o + 1]) }
    private static func u32(_ b: [UInt8], _ o: Int) throws -> Int { guard o >= 0, o + 4 <= b.count else { throw ICCMABError.malformedSection }; return Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
    private static func i32(_ b: [UInt8], _ o: Int) throws -> Int32 { Int32(bitPattern: UInt32(try u32(b, o))) }
    private static func aligned(_ value: Int) -> Int { (value + 3) & ~3 }
    private static func sectionLimit(_ start: Int, offsets: [Int], end: Int) -> Int {
        offsets.filter { $0 > start }.min() ?? end
    }

    private static func readCurves(_ b: [UInt8], at start: Int, count: Int, limit: Int) throws -> [Curve] {
        var cursor = start; var result: [Curve] = []
        for _ in 0..<count {
            guard let headerEnd = Self.checkedAdd(cursor, 12),
                  headerEnd <= limit, headerEnd <= b.count else { throw ICCMABError.malformedSection }
            let type = String(bytes: b[cursor..<cursor + 4], encoding: .ascii) ?? ""
            if type == "curv" {
                let n = try u32(b, cursor + 8)
                if n == 0 { result.append(Curve(body: .identity)); cursor += 12 }
                else if n == 1 {
                    guard let gammaEnd = Self.checkedAdd(cursor, 14), gammaEnd <= limit else { throw ICCMABError.malformedSection }
                    let gamma = Double(try u16(b, cursor + 12)) / 256.0
                    guard gamma > 0 else { throw ICCMABError.unsupportedCurve }
                    result.append(Curve(body: .gamma(gamma))); cursor += 16
                }
                else {
                    let (sampleBytes, overflow) = n.multipliedReportingOverflow(by: 2)
                    guard n <= 65535, !overflow,
                          let sectionEnd = Self.checkedAdd(cursor, 12, sampleBytes),
                          sectionEnd <= limit, sectionEnd <= b.count else { throw ICCMABError.malformedSection }
                    let values = try (0..<n).map { index in
                        guard let offset = Self.checkedAdd(cursor, 12, index * 2) else { throw ICCMABError.malformedSection }
                        return Double(try u16(b, offset)) / 65535.0
                    }
                    result.append(Curve(body: .table(values))); cursor = try Self.checkedAligned(sectionEnd)
                }
            } else if type == "para" {
                let fn = try u16(b, cursor + 8)
                let counts = [1, 3, 4, 6, 7]
                guard fn < counts.count else { throw ICCMABError.unsupportedCurve }
                let n = counts[fn]
                guard let sectionEnd = Self.checkedAdd(cursor, 12, n * 4),
                      sectionEnd <= limit, sectionEnd <= b.count else { throw ICCMABError.malformedSection }
                let params = try (0..<n).map { index in
                    guard let offset = Self.checkedAdd(cursor, 12, index * 4) else { throw ICCMABError.malformedSection }
                    return Double(try i32(b, offset)) / 65536.0
                }
                guard params[0] > 0,
                      fn == 0 || (params[1] > 0 &&
                                  (fn < 3 || params[1] * params[4] + params[2] >= 0)) else {
                    throw ICCMABError.unsupportedCurve
                }
                result.append(Curve(body: .parametric(fn, params))); cursor = try Self.checkedAligned(sectionEnd)
            } else { throw ICCMABError.unsupportedCurve }
        }
        guard cursor <= limit || cursor - limit <= 3 else { throw ICCMABError.malformedSection }
        return result
    }

    private static func readCLUT(_ b: [UInt8], at start: Int, inputChannels: Int,
                                 outputChannels: Int, limit: Int) throws -> CLUT {
        guard let headerEnd = Self.checkedAdd(start, 20),
              headerEnd <= limit, headerEnd <= b.count, (1...15).contains(inputChannels) else {
            throw ICCMABError.malformedSection
        }
        let grid = (0..<inputChannels).map { Int(b[start + $0]) }
        guard grid.allSatisfy({ (2...255).contains($0) }),
              (inputChannels..<16).allSatisfy({ b[start + $0] == 0 }),
              b[start + 16] == 1 || b[start + 16] == 2 else { throw ICCMABError.unsupportedCLUT }
        var nodeCount = 1
        for dimension in grid {
            let (next, overflow) = nodeCount.multipliedReportingOverflow(by: dimension)
            guard !overflow, next <= ICCProfileValidator.maxProfileBytes else {
                throw ICCMABError.malformedSection
            }
            nodeCount = next
        }
        let (count, nodeOverflow) = nodeCount.multipliedReportingOverflow(by: outputChannels)
        guard !nodeOverflow, count <= ICCProfileValidator.maxProfileBytes else {
            throw ICCMABError.malformedSection
        }
        let bytesPer = Int(b[start + 16]);
        let (dataBytes, overflow) = count.multipliedReportingOverflow(by: bytesPer)
        guard !overflow, let end = Self.checkedAdd(start, 20, dataBytes),
              end <= limit, end <= b.count else { throw ICCMABError.malformedSection }
        var values: [Double] = []; values.reserveCapacity(count)
        for index in 0..<count {
            guard let offset = Self.checkedAdd(start, 20, index * bytesPer) else { throw ICCMABError.malformedSection }
            values.append(bytesPer == 1 ? Double(b[offset]) / 255.0 : Double(try u16(b, offset)) / 65535.0)
        }
        return CLUT(grid: grid, outputChannels: outputChannels,
                    bytesPerSample: bytesPer, values: values)
    }

    private static func checkedAdd(_ values: Int...) -> Int? {
        var result = 0
        for value in values {
            let (next, overflow) = result.addingReportingOverflow(value)
            guard !overflow, next <= ICCProfileValidator.maxProfileBytes else { return nil }
            result = next
        }
        return result
    }

    private static func checkedAligned(_ value: Int) throws -> Int {
        guard let aligned = checkedAdd(value, 3) else { throw ICCMABError.malformedSection }
        return aligned & ~3
    }
}
