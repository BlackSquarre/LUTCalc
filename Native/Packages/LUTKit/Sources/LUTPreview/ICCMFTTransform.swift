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
    /// The tag always stores a 3x3 matrix. ICC permits it to be non-identity
    /// only when the input side is PCSXYZ; arbitrary device channels therefore
    /// require an identity matrix and never receive an invented 4D matrix.
    private let matrix: Matrix3x3?

    public init(profileData: Data, tag: String) throws {
        guard tag.utf8.count == 4 else { throw ICCMFTError.invalidTag }
        let profile = try ICCProfileValidator.validate(profileData)
        let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
        let bytes = [UInt8](payload)
        guard bytes.count >= 4 else { throw ICCMFTError.invalidTag }
        let type = String(bytes: bytes[0..<4], encoding: .ascii) ?? ""
        guard type == "mft1" || type == "mft2" else { throw ICCMFTError.invalidTag }
        guard bytes.count >= (type == "mft1" ? 48 : 52) else { throw ICCMFTError.malformedTable }
        let input = Int(bytes[8])
        let output = Int(bytes[9])
        let grid = Int(bytes[10])
        guard (1...15).contains(input), (1...15).contains(output) else {
            throw ICCMFTError.unsupportedChannels
        }
        let deviceChannels: Int?
        if tag.hasPrefix("A2B") {
            deviceChannels = input
        } else if tag.hasPrefix("B2A") {
            deviceChannels = output
        } else {
            deviceChannels = nil
        }
        if let expected = profile.colorChannelCount,
           let deviceChannels,
           expected != deviceChannels {
            throw ICCMFTError.malformedTable
        }
        // ICC.1 stores grid points in one u8 field and permits 2...255.
        // Resource limits remain enforced by checkedPower/product/sum below.
        guard (2...255).contains(grid) else { throw ICCMFTError.unsupportedGrid }
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
        let identity = matrixValues.enumerated().allSatisfy { index, value in
            let row = index / 3
            let column = index % 3
            return abs(value - (row == column ? 1.0 : 0.0)) <= 1.0 / 65536.0
        }
        // The tag carries only a 3x3 matrix. Non-three-channel device arrays
        // therefore cannot apply a matrix, even when the profile header names
        // a PCS; accepting one would silently discard declared coefficients.
        guard input == 3 || identity else {
            throw ICCMFTError.malformedTable
        }
        matrix = input == 3 ? try Matrix3x3(rowMajor: matrixValues) : nil
        let clutCount = try Self.checkedProduct(Self.checkedPower(grid, input), output)
        let sampleBytes = type == "mft1" ? 1 : 2
        self.sampleBytes = sampleBytes
        let inputByteCount = try Self.checkedProduct(try Self.checkedProduct(input, entries), sampleBytes)
        let clutByteCount = try Self.checkedProduct(clutCount, sampleBytes)
        let outputByteCount = try Self.checkedProduct(try Self.checkedProduct(output, outputEntries), sampleBytes)
        let expected = try Self.checkedSum(header, inputByteCount, clutByteCount, outputByteCount)
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
        guard inputChannels == 3, outputChannels == 3 else {
            throw ICCMFTError.unsupportedChannels
        }
        let values = try sample([input.r, input.g, input.b])
        return try RGB64(values[0], values[1], values[2])
    }

    /// Executes the complete `mft1`/`mft2` pipeline for the declared channel
    /// dimensions. The matrix remains a 3x3 ICC boundary; non-three-channel
    /// device routes use the required identity matrix and the N-dimensional
    /// CLUT directly.
    public func sample(_ input: [Double]) throws -> [Double] {
        guard input.count == inputChannels else { throw ICCMFTError.outsideDomain }
        guard input.allSatisfy(\.isFinite) else { throw ICCMFTError.nonFiniteInput }
        guard input.allSatisfy({ (0...1).contains($0) }) else {
            throw ICCMFTError.outsideDomain
        }

        // ICC mft order is input tables (A), then the optional 3x3 matrix,
        // then the CLUT. Applying the matrix to encoded input would be a
        // different transform whenever an input curve is non-linear.
        var preCLUT = zip(inputTables, input).map { Self.sample1D($0.0, $0.1) }
        if let matrix {
            guard preCLUT.count == 3 else { throw ICCMFTError.unsupportedChannels }
            let curved = try RGB64(preCLUT[0], preCLUT[1], preCLUT[2])
            let transformed = try matrix.applying(to: curved)
            preCLUT = [transformed.r, transformed.g, transformed.b]
        }
        let clutValues = (0..<outputChannels).map { channel in
            Self.sampleCLUT(clut, grid: gridPoints, input: preCLUT,
                            channel: channel, outputChannels: outputChannels)
        }
        return zip(outputTables, clutValues).map { Self.sample1D($0.0, $0.1) }
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
        let cornerCount = 1 << input.count
        for mask in 0..<cornerCount {
            var index = 0
            var weight = 1.0
            for axis in 0..<input.count {
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

    private static func checkedProduct(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow, value <= ICCProfileValidator.maxProfileBytes else {
            throw ICCMFTError.malformedTable
        }
        return value
    }

    private static func checkedSum(_ values: Int...) throws -> Int {
        var result = 0
        for value in values {
            let (next, overflow) = result.addingReportingOverflow(value)
            guard !overflow, next <= ICCProfileValidator.maxProfileBytes else {
                throw ICCMFTError.malformedTable
            }
            result = next
        }
        return result
    }
}
