import Foundation
import LUTCore

public enum ICCMFTError: Error, Equatable, Sendable {
    case invalidTag
    case unsupportedChannels
    case unsupportedGrid
    case nonFiniteInput
    case outsideDomain
    case malformedTable
    case numeric
}

/// User-imported ICC `mft1`/`mft2` transform. The payload is parsed on init and
/// used only for the requested conversion; no ICC LUT bytes are retained in the
/// value and no such bytes are bundled with the application.
public struct ICCMFTTransform: Sendable {
    public let inputChannels: Int
    public let outputChannels: Int
    public let gridPoints: Int
    public let tableEntries: Int
    public let outputTableEntries: Int
    /// Bytes per table sample: 1 for mft1 and 2 for mft2.
    public let sampleBytes: Int

    private let inputTables: [[Double]]
    private let outputTables: [[Double]]
    private let clut: [Double]
    private let matrix: Matrix3x3

    public init(profileData: Data, tag: String) throws {
        guard tag.utf8.count == 4 else { throw ICCMFTError.invalidTag }
        _ = try ICCProfileValidator.validate(profileData)
        let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
        let bytes = [UInt8](payload)
        guard bytes.count >= 4 else { throw ICCMFTError.invalidTag }
        let type = String(bytes: bytes[0..<4], encoding: .ascii) ?? ""
        guard type == "mft1" || type == "mft2" else { throw ICCMFTError.invalidTag }
        guard bytes.count >= (type == "mft1" ? 48 : 52) else { throw ICCMFTError.malformedTable }
        let input = Int(bytes[8])
        let output = Int(bytes[9])
        let grid = Int(bytes[10])
        guard input == 3, output == 3 else { throw ICCMFTError.unsupportedChannels }
        guard (2...64).contains(grid) else { throw ICCMFTError.unsupportedGrid }
        let entries = type == "mft1" ? 256 : try Self.readUInt16(bytes, at: 48)
        let outputEntries = type == "mft1" ? 256 : try Self.readUInt16(bytes, at: 50)
        guard entries >= 2, entries <= 65535, outputEntries >= 2, outputEntries <= 65535 else {
            throw ICCMFTError.malformedTable
        }
        inputChannels = input
        outputChannels = output
        gridPoints = grid
        tableEntries = entries
        outputTableEntries = outputEntries
        let header = type == "mft1" ? 48 : 52
        let matrixValues = try stride(from: 12, to: 48, by: 4).map {
            Double(try Self.readInt32(bytes, at: $0)) / 65536.0
        }
        matrix = try Matrix3x3(rowMajor: matrixValues)
        let clutCount = (try Self.checkedPower(grid, input)) * output
        let sampleBytes = type == "mft1" ? 1 : 2
        self.sampleBytes = sampleBytes
        let inputByteCount = input * entries * sampleBytes
        let clutByteCount = clutCount * sampleBytes
        let outputByteCount = output * outputEntries * sampleBytes
        let expected = header + inputByteCount + clutByteCount + outputByteCount
        guard expected == bytes.count else { throw ICCMFTError.malformedTable }
        var cursor = header
        inputTables = try (0..<input).map { _ in
            let table = try Self.readTable(bytes, at: &cursor, count: entries, sampleBytes: sampleBytes)
            return table
        }
        clut = try Self.readTable(bytes, at: &cursor, count: clutCount, sampleBytes: sampleBytes)
        outputTables = try (0..<output).map { _ in
            try Self.readTable(bytes, at: &cursor, count: outputEntries, sampleBytes: sampleBytes)
        }
    }

    public func sample(_ input: RGB64) throws -> RGB64 {
        guard input.r.isFinite, input.g.isFinite, input.b.isFinite else { throw ICCMFTError.nonFiniteInput }
        guard [input.r, input.g, input.b].allSatisfy({ (0...1).contains($0) }) else {
            throw ICCMFTError.outsideDomain
        }
        let transformed = try matrix.applying(to: input)
        let preCLUT = try RGB64(
            Self.sample1D(inputTables[0], transformed.r),
            Self.sample1D(inputTables[1], transformed.g),
            Self.sample1D(inputTables[2], transformed.b))
        let clutRGB = try RGB64(
            Self.sampleCLUT(clut, grid: gridPoints, input: [preCLUT.r, preCLUT.g, preCLUT.b], channel: 0, outputChannels: 3),
            Self.sampleCLUT(clut, grid: gridPoints, input: [preCLUT.r, preCLUT.g, preCLUT.b], channel: 1, outputChannels: 3),
            Self.sampleCLUT(clut, grid: gridPoints, input: [preCLUT.r, preCLUT.g, preCLUT.b], channel: 2, outputChannels: 3))
        return try RGB64(Self.sample1D(outputTables[0], clutRGB.r),
                         Self.sample1D(outputTables[1], clutRGB.g),
                         Self.sample1D(outputTables[2], clutRGB.b))
    }

    private static func sample1D(_ table: [Double], _ value: Double) -> Double {
        let x = min(max(value, 0), 1) * Double(table.count - 1)
        let low = Int(floor(x)); let high = min(low + 1, table.count - 1)
        let fraction = x - Double(low)
        return table[low] + (table[high] - table[low]) * fraction
    }

    private static func sampleCLUT(_ table: [Double], grid: Int, input: [Double], channel: Int,
                                  outputChannels: Int) -> Double {
        let positions = input.map { min(max($0, 0), 1) * Double(grid - 1) }
        let low = positions.map { Int(floor($0)) }
        let high = low.map { min($0 + 1, grid - 1) }
        let fractions = positions.enumerated().map { $0.1 - Double(low[$0.offset]) }
        var result = 0.0
        for mask in 0..<8 {
            var index = 0
            var weight = 1.0
            for axis in 0..<3 {
                let coordinate = ((mask >> axis) & 1) == 0 ? low[axis] : high[axis]
                weight *= ((mask >> axis) & 1) == 0 ? (1 - fractions[axis]) : fractions[axis]
                index = index * grid + coordinate
            }
            result += table[index * outputChannels + channel] * weight
        }
        return result
    }

    private static func readTable(_ bytes: [UInt8], at cursor: inout Int, count: Int,
                                  sampleBytes: Int) throws -> [Double] {
        var result: [Double] = []; result.reserveCapacity(count)
        for _ in 0..<count {
            if sampleBytes == 1 {
                guard cursor < bytes.count else { throw ICCMFTError.malformedTable }
                result.append(Double(bytes[cursor]) / 255.0); cursor += 1
            } else {
                result.append(Double(try readUInt16(bytes, at: cursor)) / 65535.0); cursor += 2
            }
        }
        return result
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) throws -> Int {
        guard offset >= 0, offset + 2 <= bytes.count else { throw ICCMFTError.malformedTable }
        return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
    }

    private static func readInt32(_ bytes: [UInt8], at offset: Int) throws -> Int32 {
        guard offset >= 0, offset + 4 <= bytes.count else { throw ICCMFTError.malformedTable }
        let bits = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 |
            UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        return Int32(bitPattern: bits)
    }

    private static func checkedPower(_ base: Int, _ exponent: Int) throws -> Int {
        var value = 1
        for _ in 0..<exponent {
            let (next, overflow) = value.multipliedReportingOverflow(by: base)
            guard !overflow, next <= ICCProfileValidator.maxProfileBytes else { throw ICCMFTError.malformedTable }
            value = next
        }
        return value
    }
}
