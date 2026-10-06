import Foundation
import LUTCore

/// ICC.1:2022-05 `multiProcessElementsType` execution for user-supplied
/// device profiles. PCS remains the three-channel XYZ/Lab encoding, while the
/// device side may use any channel count represented by the ICC color-space
/// signature (for example CMYK or 3CLR...FCLR).
///
/// The transform keeps decoded Double parameters only. It never retains the
/// source ICC bytes. The supported element set is the current ICC set of
/// formula curve sets, matrices, float32 CLUTs, and pass-through ACS markers.
public enum ICCMPEError: Error, Equatable, Sendable {
    case invalidTag
    case malformed
    case unsupportedChannels
    case unsupportedProcessingElement(String)
    case unsupportedCurve(String)
    case unsupportedSampledCurve
    case channelMismatch
    case invalidFloat
    case nonFiniteInput
    case nonFiniteResult
}

public enum ICCMPEPCSType: String, Equatable, Sendable {
    case xyz = "XYZ "
    case lab = "Lab "
}

public struct ICCMPETransform: Sendable {
    private enum CurveSegment: Sendable {
        case formula(type: Int, parameters: [Double])
        case sampled([Double])

        func applyFormula(_ input: Double) throws -> Double {
            let result: Double
            switch self {
            case let .formula(type, p):
                switch type {
                case 0:
                    result = Foundation.pow(p[1] * input + p[2], p[0]) + p[3]
                case 1:
                    result = p[1] * Foundation.log10(p[2] * Foundation.pow(input, p[0]) + p[3]) + p[4]
                case 2:
                    result = p[0] * Foundation.pow(p[1], p[2] * input + p[3]) + p[4]
                default:
                    throw ICCMPEError.unsupportedCurve("parf-\(type)")
                }
            case .sampled:
                throw ICCMPEError.unsupportedSampledCurve
            }
            guard result.isFinite, abs(result) <= Double(Float.greatestFiniteMagnitude) else {
                throw ICCMPEError.nonFiniteResult
            }
            return result
        }
    }

    private struct Curve: Sendable {
        let breakpoints: [Double]
        let segments: [CurveSegment]

        func apply(_ input: Double) throws -> Double {
            let index = breakpoints.firstIndex(where: { input <= $0 }) ?? segments.count - 1
            switch segments[index] {
            case .formula:
                return try segments[index].applyFormula(input)
            case .sampled(let samples):
                // The first point of a sampled segment is the preceding
                // segment's value at the lower breakpoint. Stored samples
                // then represent j/n for j=1...n across the interval.
                guard index > 0, index - 1 < breakpoints.count,
                      index < segments.count else { throw ICCMPEError.malformed }
                let lower = breakpoints[index - 1]
                // ICC.1 supplies the next breakpoint for an interior sampled
                // segment. A final sampled segment extends to the normalized
                // curve-domain endpoint (1.0); its last stored sample is the
                // endpoint value. The first segment remains invalid because
                // it has no preceding value for the implicit j=0 sample.
                let upper = index < breakpoints.count ? breakpoints[index] : 1.0
                guard upper > lower, !samples.isEmpty else {
                    throw ICCMPEError.malformed
                }
                let start = try apply(lower)
                let position = min(max((input - lower) / (upper - lower), 0.0), 1.0) * Double(samples.count)
                if position <= 0 { return start }
                if position >= Double(samples.count) { return samples[samples.count - 1] }
                let lowerIndex = Int(floor(position))
                let fraction = position - Double(lowerIndex)
                let lowerValue = lowerIndex == 0 ? start : samples[lowerIndex - 1]
                let upperValue = samples[lowerIndex]
                return lowerValue + (upperValue - lowerValue) * fraction
            }
        }
    }

    private struct MatrixElement: Sendable {
        let inputChannels: Int
        let outputChannels: Int
        let values: [Double]

        func apply(_ input: [Double]) -> [Double] {
            (0..<outputChannels).map { row in
                let rowStart = row * (inputChannels + 1)
                return values[rowStart + inputChannels] + (0..<inputChannels).reduce(0.0) { partial, column in
                    partial + values[rowStart + column] * input[column]
                }
            }
        }
    }

    private struct CLUTElement: Sendable {
        let grid: [Int]
        let outputChannels: Int
        let values: [Double]

        func apply(_ input: [Double]) -> [Double] {
            let position = zip(input, grid).map { min(max($0.0, 0.0), 1.0) * Double($0.1 - 1) }
            let low = position.map { Int(floor($0)) }
            let high = zip(low, grid).map { min($0.0 + 1, $0.1 - 1) }
            let fraction = zip(position, low).map { $0.0 - Double($0.1) }
            var output = Array(repeating: 0.0, count: outputChannels)
            let inputChannelCount = grid.count
            let cornerCount = 1 << inputChannelCount
            // ICC.1:2022-05 10.16.2.4 stores the first input dimension
            // least rapidly and the last dimension most rapidly.
            var strides = Array(repeating: 1, count: inputChannelCount)
            if inputChannelCount > 1 {
                for axis in 0..<(inputChannelCount - 1) {
                    strides[axis] = grid[(axis + 1)..<inputChannelCount]
                        .reduce(1, *)
                }
            }
            for mask in 0..<cornerCount {
                var index = 0
                var weight = 1.0
                for axis in 0..<inputChannelCount {
                    let upper = (mask & (1 << axis)) != 0
                    index += (upper ? high[axis] : low[axis]) * strides[axis]
                    weight *= upper ? fraction[axis] : (1 - fraction[axis])
                }
                for channel in 0..<outputChannels {
                    output[channel] += values[index * outputChannels + channel] * weight
                }
            }
            return output
        }
    }

    private enum Element: Sendable {
        case curves([Curve])
        case matrix(MatrixElement)
        case clut(CLUTElement)
        case passthrough(Int)

        var inputChannels: Int {
            switch self {
            case .curves(let curves): curves.count
            case .matrix(let matrix): matrix.inputChannels
            case .clut(let clut): clut.grid.count
            case .passthrough(let channels): channels
            }
        }

        var outputChannels: Int {
            switch self {
            case .curves(let curves): curves.count
            case .matrix(let matrix): matrix.outputChannels
            case .clut(let clut): clut.outputChannels
            case .passthrough(let channels): channels
            }
        }

        func apply(_ input: [Double]) throws -> [Double] {
            switch self {
            case .curves(let curves):
                return try curves.enumerated().map { try $0.element.apply(input[$0.offset]) }
            case .matrix(let matrix):
                return matrix.apply(input)
            case .clut(let clut):
                return clut.apply(input)
            case .passthrough:
                return input
            }
        }
    }

    public let inputChannels: Int
    public let outputChannels: Int
    public let tag: String
    public let pcs: ICCMPEPCSType

    private let elements: [Element]

    public init(profileData: Data, tag: String) throws {
        try self.init(profileData: profileData, tag: tag, deviceLinkOutputChannels: nil)
    }

    /// Internal device-link entry point. A device-link MPE payload uses the
    /// same `mpet` execution rules, but its output is the link's declared
    /// color space rather than ICC PCS XYZ/Lab.
    init(profileData: Data, tag: String, deviceLinkOutputChannels: Int?) throws {
        guard ["D2B0", "B2D0", "D2B1", "B2D1", "D2B2", "B2D2", "D2B3", "B2D3", "A2B0"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let profile = try ICCProfileValidator.validate(profileData)
        guard let deviceChannels = profile.colorChannelCount,
              (1...15).contains(deviceChannels),
              let pcs = ICCMPEPCSType(rawValue: profile.pcsSignature) ??
                (deviceLinkOutputChannels != nil ? .xyz : nil) else {
            throw ICCMPEError.unsupportedChannels
        }
        let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
        let bytes = [UInt8](payload)
        guard bytes.count >= 16,
              String(bytes: bytes[0..<4], encoding: .ascii) == "mpet",
              bytes[4..<8].allSatisfy({ $0 == 0 }) else {
            throw ICCMPEError.malformed
        }

        let input = try Self.u16(bytes, at: 8)
        let output = try Self.u16(bytes, at: 10)
        let count = try Self.u32(bytes, at: 12)
        let deviceToPCS = tag.hasPrefix("D2B") || tag == "A2B0"
        let expectedInput = deviceToPCS ? deviceChannels : 3
        let expectedOutput = deviceToPCS
            ? (deviceLinkOutputChannels ?? 3)
            : deviceChannels
        guard input == expectedInput, output == expectedOutput else {
            throw ICCMPEError.unsupportedChannels
        }
        guard (1...4096).contains(count) else { throw ICCMPEError.malformed }
        guard let tableBytes = Self.checkedAdd(Self.checkedMultiply(count, 8) ?? -1, 16),
              tableBytes >= 16 else { throw ICCMPEError.malformed }
        let tableEnd = tableBytes
        guard tableEnd <= bytes.count else { throw ICCMPEError.malformed }

        var parsed: [Element] = []
        var ranges: [(Int, Int)] = []
        var previousOutput = input
        for index in 0..<count {
            guard let position = Self.checkedAdd(Self.checkedMultiply(index, 8) ?? -1, 16) else {
                throw ICCMPEError.malformed
            }
            let offset = try Self.u32(bytes, at: position)
            let size = try Self.u32(bytes, at: position + 4)
            let (end, overflow) = offset.addingReportingOverflow(size)
            guard offset >= tableEnd, offset % 4 == 0, size >= 12,
                  !overflow, end <= bytes.count else { throw ICCMPEError.malformed }
            ranges.append((offset, end))
            let element = try Self.parseElement(bytes, offset: offset, size: size)
            guard element.inputChannels == previousOutput else { throw ICCMPEError.channelMismatch }
            previousOutput = element.outputChannels
            parsed.append(element)
        }
        guard previousOutput == output else { throw ICCMPEError.channelMismatch }
        try Self.validateSharedRanges(ranges)

        self.inputChannels = input
        self.outputChannels = output
        self.tag = tag
        self.pcs = pcs
        self.elements = parsed
    }

    /// Executes an MPE stage for a device-link route without imposing PCS
    /// XYZ/Lab conversion on the output vector.
    func sample(_ input: [Double]) throws -> [Double] {
        try apply(input)
    }

    /// Executes a device-to-PCS transform from a D2B0...D2B3 tag.
    public func deviceRGBToPCSXYZ(_ rgb: RGB64) throws -> XYZ64 {
        guard pcs == .xyz, ["D2B0", "D2B1", "D2B2", "D2B3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try deviceToPCSXYZ([rgb.r, rgb.g, rgb.b])
        return values
    }

    /// Executes a device-to-PCS transform for any supported ICC device channel count.
    public func deviceToPCSXYZ(_ device: [Double]) throws -> XYZ64 {
        guard pcs == .xyz, ["D2B0", "D2B1", "D2B2", "D2B3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try apply(device)
        return try XYZ64(values[0], values[1], values[2])
    }

    /// Executes a device-to-PCS transform whose PCS is direct float32 Lab.
    public func deviceRGBToPCSLab(_ rgb: RGB64) throws -> CIELABColor {
        guard pcs == .lab, ["D2B0", "D2B1", "D2B2", "D2B3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try deviceToPCSLab([rgb.r, rgb.g, rgb.b])
        return values
    }

    /// Executes a device-to-PCS Lab transform for any supported ICC device channel count.
    public func deviceToPCSLab(_ device: [Double]) throws -> CIELABColor {
        guard pcs == .lab, ["D2B0", "D2B1", "D2B2", "D2B3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try apply(device)
        return try ICCLabPCS.decodeFloat(values)
    }

    /// Executes a PCS-to-device transform from a B2D0...B2D3 tag.
    public func pcsXYZToDeviceRGB(_ xyz: XYZ64) throws -> RGB64 {
        guard pcs == .xyz, ["B2D0", "B2D1", "B2D2", "B2D3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try pcsXYZToDevice(xyz)
        return try RGB64(values[0], values[1], values[2])
    }

    /// Executes a PCS-to-device transform for any supported ICC device channel count.
    public func pcsXYZToDevice(_ xyz: XYZ64) throws -> [Double] {
        guard pcs == .xyz, ["B2D0", "B2D1", "B2D2", "B2D3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        return try apply([xyz.x, xyz.y, xyz.z])
    }

    /// Executes a PCS-to-device transform whose PCS is direct float32 Lab.
    public func pcsLabToDeviceRGB(_ lab: CIELABColor) throws -> RGB64 {
        guard pcs == .lab, ["B2D0", "B2D1", "B2D2", "B2D3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let output = try pcsLabToDevice(lab)
        return try RGB64(output[0], output[1], output[2])
    }

    /// Executes a PCS Lab-to-device transform for any supported ICC device channel count.
    public func pcsLabToDevice(_ lab: CIELABColor) throws -> [Double] {
        guard pcs == .lab, ["B2D0", "B2D1", "B2D2", "B2D3"].contains(tag) else {
            throw ICCMPEError.invalidTag
        }
        let values = try ICCLabPCS.encodeFloat(lab)
        let output = try apply(values)
        return output
    }

    private func apply(_ input: [Double]) throws -> [Double] {
        guard input.count == inputChannels, input.allSatisfy(\.isFinite) else {
            throw ICCMPEError.nonFiniteInput
        }
        guard input.allSatisfy({ abs($0) <= Double(Float.greatestFiniteMagnitude) }) else {
            throw ICCMPEError.nonFiniteInput
        }
        var values = input
        for element in elements {
            values = try element.apply(values)
            guard values.allSatisfy({ $0.isFinite && abs($0) <= Double(Float.greatestFiniteMagnitude) }) else {
                throw ICCMPEError.nonFiniteResult
            }
        }
        return values
    }

    private static func parseElement(_ bytes: [UInt8], offset: Int, size: Int) throws -> Element {
        guard let end = Self.checkedAdd(offset, size) else { throw ICCMPEError.malformed }
        let signature = String(bytes: bytes[offset..<offset + 4], encoding: .ascii) ?? ""
        guard bytes[offset + 4..<offset + 8].allSatisfy({ $0 == 0 }) else {
            throw ICCMPEError.malformed
        }
        let input = try u16(bytes, at: offset + 8)
        let output = try u16(bytes, at: offset + 10)
        // ICC processing elements describe an actual channel vector. Empty
        // vectors are not a valid MPE stage, even though the fields are
        // encoded as unsigned 16-bit values.
        guard input > 0, output > 0 else { throw ICCMPEError.unsupportedChannels }
        switch signature {
        case "cvst":
            guard input == output else { throw ICCMPEError.unsupportedChannels }
            return try parseCurves(bytes, offset: offset, end: end, input: input)
        case "matf":
            guard let inputStride = Self.checkedAdd(input, 1),
                  let valueCount = Self.checkedMultiply(output, inputStride),
                  let valueBytes = Self.checkedMultiply(valueCount, 4),
                  let expectedSize = Self.checkedAdd(12, valueBytes),
                  size == expectedSize else { throw ICCMPEError.malformed }
            var values: [Double] = []
            values.reserveCapacity(valueCount)
            for index in 0..<valueCount {
                guard let byteOffset = Self.checkedAdd(Self.checkedMultiply(index, 4) ?? -1, Self.checkedAdd(offset, 12) ?? -1) else {
                    throw ICCMPEError.malformed
                }
                values.append(try float32(bytes, at: byteOffset))
            }
            return .matrix(MatrixElement(inputChannels: input, outputChannels: output, values: values))
        case "clut":
            return try parseCLUT(bytes, offset: offset, end: end, input: input, output: output)
        case "bACS", "eACS":
            guard input == output, size == 16 else { throw ICCMPEError.malformed }
            return .passthrough(input)
        default:
            throw ICCMPEError.unsupportedProcessingElement(signature)
        }
    }

    private static func parseCurves(_ bytes: [UInt8], offset: Int, end: Int,
                                    input: Int) throws -> Element {
        guard let curveTableBytes = Self.checkedMultiply(input, 8),
              let tableEnd = Self.checkedAdd(Self.checkedAdd(offset, 12) ?? -1, curveTableBytes) else {
            throw ICCMPEError.malformed
        }
        guard tableEnd <= end else { throw ICCMPEError.malformed }
        var curves: [Curve] = []
        var ranges: [(Int, Int)] = []
        for index in 0..<input {
            guard let position = Self.checkedAdd(Self.checkedMultiply(index, 8) ?? -1, Self.checkedAdd(offset, 12) ?? -1) else {
                throw ICCMPEError.malformed
            }
            let curveOffset = try u32(bytes, at: position)
            let curveSize = try u32(bytes, at: position + 4)
            guard let start = Self.checkedAdd(offset, curveOffset) else {
                throw ICCMPEError.malformed
            }
            let (curveEnd, overflow) = start.addingReportingOverflow(curveSize)
            guard curveOffset >= 12 + curveTableBytes, curveOffset % 4 == 0, !overflow,
                  curveEnd <= end, curveSize >= 12 else { throw ICCMPEError.malformed }
            ranges.append((start, curveEnd))
            curves.append(try parseCurve(bytes, start: start, end: curveEnd))
        }
        try validateSharedRanges(ranges)
        return .curves(curves)
    }

    private static func parseCurve(_ bytes: [UInt8], start: Int, end: Int) throws -> Curve {
        guard String(bytes: bytes[start..<start + 4], encoding: .ascii) == "curf",
              bytes[start + 4..<start + 8].allSatisfy({ $0 == 0 }) else {
            throw ICCMPEError.unsupportedCurve("curf")
        }
        let segmentCount = try u16(bytes, at: start + 8)
        guard (1...4096).contains(segmentCount) else { throw ICCMPEError.malformed }
        let breakpointStart = start + 12
        guard let breakpointBytes = Self.checkedMultiply(segmentCount - 1, 4),
              let segmentStart = Self.checkedAdd(breakpointStart, breakpointBytes) else {
            throw ICCMPEError.malformed
        }
        guard segmentStart <= end else { throw ICCMPEError.malformed }
        let breakpoints = try (0..<(segmentCount - 1)).map {
            try float32(bytes, at: breakpointStart + $0 * 4)
        }
        // ICC.1 defines breakpoints over the float32 curve input domain;
        // unlike CLUT coordinates they are not restricted to 0...1.
        guard breakpoints.allSatisfy({ $0.isFinite }),
              zip(breakpoints, breakpoints.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw ICCMPEError.malformed
        }

        var cursor = segmentStart
        var segments: [CurveSegment] = []
        for segmentIndex in 0..<segmentCount {
            guard let headerEnd = Self.checkedAdd(cursor, 12),
                  headerEnd <= end else { throw ICCMPEError.malformed }
            let type = String(bytes: bytes[cursor..<cursor + 4], encoding: .ascii) ?? ""
            guard bytes[cursor + 4..<cursor + 8].allSatisfy({ $0 == 0 }) else {
                throw ICCMPEError.malformed
            }
            if type == "parf" {
                guard bytes[cursor + 10..<cursor + 12].allSatisfy({ $0 == 0 }) else {
                    throw ICCMPEError.malformed
                }
                let function = try u16(bytes, at: cursor + 8)
                let parameterCount: Int
                switch function {
                case 0: parameterCount = 4
                case 1, 2: parameterCount = 5
                default: throw ICCMPEError.unsupportedCurve("parf-\(function)")
                }
                guard let parameterBytes = Self.checkedMultiply(parameterCount, 4),
                      let length = Self.checkedAdd(12, parameterBytes),
                      let segmentEnd = Self.checkedAdd(cursor, length),
                      segmentEnd <= end else { throw ICCMPEError.malformed }
                let parameters = try (0..<parameterCount).map {
                    guard let byteOffset = Self.checkedAdd(Self.checkedMultiply($0, 4) ?? -1, Self.checkedAdd(cursor, 12) ?? -1) else {
                        throw ICCMPEError.malformed
                    }
                    return try float32(bytes, at: byteOffset)
                }
                segments.append(.formula(type: function, parameters: parameters))
                cursor += length
            } else if type == "samf" {
                // The first sampled segment has no preceding curve value for
                // its implicit j=0 sample. A final sampled segment is valid:
                // its preceding segment supplies that implicit start and its
                // last stored sample is the curve endpoint.
                guard segmentIndex > 0 else {
                    throw ICCMPEError.malformed
                }
                let count = try u32(bytes, at: cursor + 8)
                guard count >= 1 else { throw ICCMPEError.malformed }
                let (sampleBytes, overflow) = count.multipliedReportingOverflow(by: 4)
                let (length, lengthOverflow) = (12).addingReportingOverflow(sampleBytes)
                guard !overflow, !lengthOverflow,
                      let segmentEnd = Self.checkedAdd(cursor, length),
                      segmentEnd <= end else {
                    throw ICCMPEError.malformed
                }
                let samples = try (0..<count).map {
                    guard let byteOffset = Self.checkedAdd(Self.checkedMultiply($0, 4) ?? -1, Self.checkedAdd(cursor, 12) ?? -1) else {
                        throw ICCMPEError.malformed
                    }
                    return try float32(bytes, at: byteOffset)
                }
                segments.append(.sampled(samples))
                cursor += length
            } else {
                throw ICCMPEError.unsupportedCurve(type)
            }
        }
        guard cursor <= end, end - cursor <= 3,
              bytes[cursor..<end].allSatisfy({ $0 == 0 }) else {
            throw ICCMPEError.malformed
        }
        return Curve(breakpoints: breakpoints, segments: segments)
    }

    private static func parseCLUT(_ bytes: [UInt8], offset: Int, end: Int,
                                  input: Int, output: Int) throws -> Element {
        guard (1...16).contains(input), (1...65535).contains(output) else {
            throw ICCMPEError.malformed
        }
        guard offset + 28 <= end else { throw ICCMPEError.malformed }
        let grid = (0..<input).map { Int(bytes[offset + 12 + $0]) }
        guard grid.allSatisfy({ (2...255).contains($0) }),
              (input..<16).allSatisfy({ bytes[offset + 12 + $0] == 0 }) else {
            throw ICCMPEError.malformed
        }
        let count = try grid.reduce(1) { partial, value in
            let (next, overflow) = partial.multipliedReportingOverflow(by: value)
            guard !overflow else { throw ICCMPEError.malformed }
            return next
        }
        let valueCount = count.multipliedReportingOverflow(by: output)
        let valueBytes = valueCount.partialValue.multipliedReportingOverflow(by: 4)
        let clutEnd = (offset + 28).addingReportingOverflow(valueBytes.partialValue)
        guard !valueCount.overflow, !valueBytes.overflow, !clutEnd.overflow,
              clutEnd.partialValue == end else {
            throw ICCMPEError.malformed
        }
        var values: [Double] = []
        values.reserveCapacity(valueCount.partialValue)
        for index in 0..<valueCount.partialValue {
            values.append(try float32(bytes, at: offset + 28 + index * 4))
        }
        return .clut(CLUTElement(grid: grid, outputChannels: output, values: values))
    }

    private static func u16(_ bytes: [UInt8], at offset: Int) throws -> Int {
        guard offset >= 0, offset + 2 <= bytes.count else { throw ICCMPEError.malformed }
        return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
    }

    private static func checkedAdd(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func checkedMultiply(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func u32(_ bytes: [UInt8], at offset: Int) throws -> Int {
        guard offset >= 0, offset + 4 <= bytes.count else { throw ICCMPEError.malformed }
        let value = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 |
            UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        guard let integer = Int(exactly: value) else { throw ICCMPEError.malformed }
        return integer
    }

    private static func float32(_ bytes: [UInt8], at offset: Int) throws -> Double {
        guard offset >= 0, offset + 4 <= bytes.count else { throw ICCMPEError.malformed }
        let bits = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 |
            UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        let value = Float(bitPattern: bits)
        guard value.isFinite else { throw ICCMPEError.invalidFloat }
        return Double(value)
    }

    private static func validateSharedRanges(_ ranges: [(Int, Int)]) throws {
        let ordered = ranges.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        for pair in zip(ordered, ordered.dropFirst()) where pair.0.1 > pair.1.0 {
            guard pair.0 == pair.1 else { throw ICCMPEError.malformed }
        }
    }
}
