import Foundation
import LUTCore

/// Stages retained by the bounded ICC matrix/TRC CPU path.
public enum ICCMatrixTRCStageID: String, Codable, Sendable {
    case encodedRGB
    case decodeTransfer
    case linearRGB
    case xyzInput
    case matrix
    case xyzOutput
    case encodeTransfer
}

public struct ICCMatrixTRCStageValue: Equatable, Sendable {
    public let id: ICCMatrixTRCStageID
    public let rgb: RGB64?
    public let xyz: XYZ64?

    public init(id: ICCMatrixTRCStageID, rgb: RGB64? = nil, xyz: XYZ64? = nil) {
        self.id = id
        self.rgb = rgb
        self.xyz = xyz
    }
}

public struct ICCMatrixTRCTrace: Equatable, Sendable {
    public let xyzOutput: XYZ64?
    public let encodedRGBOutput: RGB64?
    public let stages: [ICCMatrixTRCStageValue]

    public init(
        xyzOutput: XYZ64?,
        encodedRGBOutput: RGB64?,
        stages: [ICCMatrixTRCStageValue]
    ) {
        self.xyzOutput = xyzOutput
        self.encodedRGBOutput = encodedRGBOutput
        self.stages = stages
    }
}

public enum ICCMatrixTRCError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case missingTag(String)
    case malformedTag(String)
    case unsupportedCurve(String)
    case outsideDomain(stage: ICCMatrixTRCStageID)
    case nonUnique(stage: ICCMatrixTRCStageID)
    case numeric(stage: ICCMatrixTRCStageID)
}

/// A deliberately bounded ICC v2/v4 RGB matrix/TRC interpretation.
///
/// It consumes only the profile metadata already validated by `ICCProfileValidator`:
/// `rXYZ`, `gXYZ`, `bXYZ`, and `wtpt`, together with an ICC `curv` (identity,
/// u8Fixed8 gamma, or uniformly sampled uInt16 curve with linear interpolation) or `para(type=0...4)`
/// transfer form for each RGB channel. Sampled curves are read only from the
/// user supplied profile; no sampled curve is bundled as an application asset.
/// It does not create an ICC color-management workspace, use Core Image, or
/// infer a display profile.
public struct ICCMatrixTRCTransform: Sendable {
    public let profileWhitePoint: XYZ64
    private let matrix: Matrix3x3
    private let inverse: Matrix3x3
    private let curves: [Curve]

    public init(profileData: Data) throws {
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCMatrixTRCError.invalidProfile
        }
        guard profile.colorSpaceSignature == "RGB " else {
            throw ICCMatrixTRCError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "XYZ " else {
            throw ICCMatrixTRCError.unsupportedPCS
        }
        var tags: [String: ICCProfileTagValidation] = [:]
        for tag in profile.tags { tags[tag.signature] = tag }

        func required(_ signature: String) throws -> ICCProfileTagValidation {
            guard let tag = tags[signature] else { throw ICCMatrixTRCError.missingTag(signature) }
            return tag
        }

        let red = try Self.xyzValues(required("rXYZ"), signature: "rXYZ")
        let green = try Self.xyzValues(required("gXYZ"), signature: "gXYZ")
        let blue = try Self.xyzValues(required("bXYZ"), signature: "bXYZ")
        let white = try Self.xyzValues(required("wtpt"), signature: "wtpt")
        guard white.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw ICCMatrixTRCError.malformedTag("wtpt")
        }
        profileWhitePoint = try XYZ64(white[0], white[1], white[2])
        matrix = try Matrix3x3(rowMajor: [
            red[0], green[0], blue[0],
            red[1], green[1], blue[1],
            red[2], green[2], blue[2],
        ])
        do {
            inverse = try matrix.inverted()
        } catch {
            throw ICCMatrixTRCError.numeric(stage: .matrix)
        }
        curves = try ["rTRC", "gTRC", "bTRC"].map { try Self.curve(required($0), signature: $0) }
    }

    public func encodedRGBToXYZ(_ encoded: RGB64) throws -> XYZ64 {
        try traceEncodedRGBToXYZ(encoded).xyzOutput!
    }

    public func xyzToEncodedRGB(_ xyz: XYZ64) throws -> RGB64 {
        try traceXYZToEncodedRGB(xyz).encodedRGBOutput!
    }

    public func traceEncodedRGBToXYZ(_ encoded: RGB64) throws -> ICCMatrixTRCTrace {
        try validateUnitDomain(encoded, stage: .decodeTransfer)
        let linear = try RGB64(
            curves[0].decode(encoded.r), curves[1].decode(encoded.g), curves[2].decode(encoded.b)
        )
        let output: XYZ64
        do {
            let transformed = try matrix.applying(to: linear)
            output = try XYZ64(transformed.r, transformed.g, transformed.b)
        } catch {
            throw ICCMatrixTRCError.numeric(stage: .matrix)
        }
        return ICCMatrixTRCTrace(
            xyzOutput: output,
            encodedRGBOutput: nil,
            stages: [
                ICCMatrixTRCStageValue(id: .encodedRGB, rgb: encoded),
                ICCMatrixTRCStageValue(id: .decodeTransfer),
                ICCMatrixTRCStageValue(id: .linearRGB, rgb: linear),
                ICCMatrixTRCStageValue(id: .matrix),
                ICCMatrixTRCStageValue(id: .xyzOutput, xyz: output),
            ]
        )
    }

    public func traceXYZToEncodedRGB(_ xyz: XYZ64) throws -> ICCMatrixTRCTrace {
        let linear: RGB64
        do {
            linear = try inverse.applying(to: RGB64(xyz.x, xyz.y, xyz.z))
        } catch {
            throw ICCMatrixTRCError.numeric(stage: .matrix)
        }
        let encoded = try RGB64(
            curves[0].encode(linear.r), curves[1].encode(linear.g), curves[2].encode(linear.b)
        )
        try validateUnitDomain(encoded, stage: .encodeTransfer)
        return ICCMatrixTRCTrace(
            xyzOutput: nil,
            encodedRGBOutput: encoded,
            stages: [
                ICCMatrixTRCStageValue(id: .xyzInput, xyz: xyz),
                ICCMatrixTRCStageValue(id: .matrix, rgb: linear),
                ICCMatrixTRCStageValue(id: .linearRGB, rgb: linear),
                ICCMatrixTRCStageValue(id: .encodeTransfer),
                ICCMatrixTRCStageValue(id: .encodedRGB, rgb: encoded),
            ]
        )
    }

    private static func xyzValues(
        _ tag: ICCProfileTagValidation,
        signature: String
    ) throws -> [Double] {
        guard tag.typeSignature == "XYZ ", let values = tag.fixedPointValues, values.count == 3,
              values.allSatisfy(\.isFinite) else {
            throw ICCMatrixTRCError.malformedTag(signature)
        }
        return values
    }

    private static func curve(
        _ tag: ICCProfileTagValidation,
        signature: String
    ) throws -> Curve {
        switch tag.typeSignature {
        case "curv":
            if tag.structureValue == 0, tag.curveValues?.isEmpty == true {
                return .identity
            }
            guard let count = tag.structureValue, let values = tag.curveValues else {
                throw ICCMatrixTRCError.malformedTag(signature)
            }
            if count == 1 {
                guard values.count == 1, values[0].isFinite, values[0] > 0 else {
                    throw ICCMatrixTRCError.unsupportedCurve("curv:\(count)")
                }
                return .gamma(values[0])
            }
            guard count > 1, values.count == count,
                  values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
                throw ICCMatrixTRCError.unsupportedCurve("curv:\(count)")
            }
            return .sampled(values)
        case "para":
            guard let functionType = tag.parametricFunctionType,
                  let values = tag.fixedPointValues else {
                throw ICCMatrixTRCError.malformedTag(signature)
            }
            switch functionType {
            case 0 where values.count == 1 && values[0] > 0:
                return .gamma(values[0])
            case 1 where values.count == 3 && values[0] > 0 && values[1] > 0:
                return .parametricOne(values)
            case 2 where values.count == 4 && values[0] > 0 && values[1] > 0:
                return .parametricTwo(values)
            case 3 where values.count == 5 && values[0] > 0 && values[1] > 0 &&
                         values[1] * values[4] + values[2] >= 0:
                return .parametricThree(values)
            case 4 where values.count == 7 && values[0] > 0 && values[1] > 0 && values[3] > 0 &&
                       values[1] * values[4] + values[2] >= 0:
                return .parametricFour(values)
            default:
                throw ICCMatrixTRCError.unsupportedCurve("para:\(functionType)")
            }
        default:
            throw ICCMatrixTRCError.unsupportedCurve(tag.typeSignature)
        }
    }

    private func validateUnitDomain(_ rgb: RGB64, stage: ICCMatrixTRCStageID) throws {
        guard (0...1).contains(rgb.r), (0...1).contains(rgb.g), (0...1).contains(rgb.b) else {
            throw ICCMatrixTRCError.outsideDomain(stage: stage)
        }
    }
}

private enum Curve: Sendable {
    case identity
    case gamma(Double)
    case sampled([Double])
    case parametricOne([Double])
    case parametricTwo([Double])
    case parametricThree([Double])
    case parametricFour([Double])

    func decode(_ value: Double) -> Double {
        switch self {
        case .identity: return value
        case let .gamma(gamma): return Foundation.pow(value, gamma)
        case let .sampled(values):
            let scaled = value * Double(values.count - 1)
            let lower = min(Int(floor(scaled)), values.count - 2)
            let fraction = scaled - Double(lower)
            return values[lower] + (values[lower + 1] - values[lower]) * fraction
        case let .parametricOne(p):
            let g = p[0], a = p[1], b = p[2]
            return value >= -b / a ? Foundation.pow(a * value + b, g) : 0
        case let .parametricTwo(p):
            let g = p[0], a = p[1], b = p[2], c = p[3]
            return value >= -b / a ? Foundation.pow(a * value + b, g) + c : c
        case let .parametricThree(p):
            let g = p[0], a = p[1], b = p[2], c = p[3], d = p[4]
            return value >= d ? Foundation.pow(a * value + b, g) + c : 0
        case let .parametricFour(p):
            let g = p[0], a = p[1], b = p[2], c = p[3], d = p[4], e = p[5], f = p[6]
            return value >= d ? Foundation.pow(a * value + b, g) + e : c * value + f
        }
    }

    func encode(_ value: Double) throws -> Double {
        guard value.isFinite, value >= 0 else { throw ICCMatrixTRCError.outsideDomain(stage: .encodeTransfer) }
        switch self {
        case .identity: return value
        case let .gamma(gamma): return Foundation.pow(value, 1 / gamma)
        case let .sampled(values): return try Self.invertSampled(values, value: value)
        case let .parametricOne(p):
            let g = p[0], a = p[1], b = p[2]
            return try Self.invertFlat(value, g: g, a: a, b: b, offset: 0)
        case let .parametricTwo(p):
            let g = p[0], a = p[1], b = p[2], c = p[3]
            return try Self.invertFlat(value, g: g, a: a, b: b, offset: c)
        case let .parametricThree(p):
            let g = p[0], a = p[1], b = p[2], c = p[3], d = p[4]
            return try Self.invertPiecewise(value, g: g, a: a, b: b,
                                            highOffset: c, d: d, lowSlope: 0, lowOffset: 0)
        case let .parametricFour(p):
            let g = p[0], a = p[1], b = p[2], c = p[3], d = p[4], e = p[5], f = p[6]
            return try Self.invertPiecewise(value, g: g, a: a, b: b,
                                            highOffset: e, d: d, lowSlope: c, lowOffset: f)
        }
    }

    private static func invertSampled(_ values: [Double], value: Double) throws -> Double {
        guard values.count >= 2 else {
            throw ICCMatrixTRCError.numeric(stage: .encodeTransfer)
        }
        let tolerance = 2e-12 * max(1, abs(value))
        var candidate: Double?

        for index in 0..<(values.count - 1) {
            let y0 = values[index]
            let y1 = values[index + 1]
            if y0 == y1 {
                if abs(value - y0) <= tolerance {
                    throw ICCMatrixTRCError.nonUnique(stage: .encodeTransfer)
                }
                continue
            }
            let fraction = (value - y0) / (y1 - y0)
            guard fraction.isFinite, fraction >= -tolerance, fraction <= 1 + tolerance else {
                continue
            }
            let clamped = min(1, max(0, fraction))
            let x = (Double(index) + clamped) / Double(values.count - 1)
            let reconstructed = y0 + (y1 - y0) * clamped
            guard abs(reconstructed - value) <= tolerance else { continue }
            if let candidate {
                if abs(candidate - x) > tolerance {
                    throw ICCMatrixTRCError.nonUnique(stage: .encodeTransfer)
                }
            } else {
                candidate = x
            }
        }

        guard let candidate else {
            throw ICCMatrixTRCError.outsideDomain(stage: .encodeTransfer)
        }
        return candidate
    }

    private static func invertFlat(_ value: Double, g: Double, a: Double,
                                   b: Double, offset: Double) throws -> Double {
        let threshold = -b / a
        if value == offset && threshold > 0 {
            throw ICCMatrixTRCError.nonUnique(stage: .encodeTransfer)
        }
        let base = value - offset
        guard base >= 0 else { throw ICCMatrixTRCError.outsideDomain(stage: .encodeTransfer) }
        let candidate = (Foundation.pow(base, 1 / g) - b) / a
        let tolerance = 2e-12 * max(1, abs(value))
        guard candidate.isFinite, (0...1).contains(candidate), candidate >= threshold,
              abs(Foundation.pow(a * candidate + b, g) + offset - value) <= tolerance else {
            throw ICCMatrixTRCError.outsideDomain(stage: .encodeTransfer)
        }
        return candidate
    }

    private static func invertPiecewise(
        _ value: Double, g: Double, a: Double, b: Double,
        highOffset: Double, d: Double, lowSlope: Double, lowOffset: Double
    ) throws -> Double {
        var candidates: [Double] = []
        let tolerance = 2e-12 * max(1, abs(value))

        if lowSlope == 0 {
            if abs(value - lowOffset) <= tolerance, d > 0 {
                throw ICCMatrixTRCError.nonUnique(stage: .encodeTransfer)
            }
        } else {
            let low = (value - lowOffset) / lowSlope
            if low.isFinite, (0...1).contains(low), low < d,
               abs(lowSlope * low + lowOffset - value) <= tolerance {
                candidates.append(low)
            }
        }

        let highBase = value - highOffset
        if highBase >= 0 {
            let high = (Foundation.pow(highBase, 1 / g) - b) / a
            if high.isFinite, (0...1).contains(high), high >= d,
               a * high + b >= 0,
               abs(Foundation.pow(a * high + b, g) + highOffset - value) <= tolerance {
                candidates.append(high)
            }
        }

        guard let first = candidates.first else {
            throw ICCMatrixTRCError.outsideDomain(stage: .encodeTransfer)
        }
        guard candidates.count == 1 || abs(candidates[1] - first) <= 2e-12 else {
            throw ICCMatrixTRCError.nonUnique(stage: .encodeTransfer)
        }
        return first
    }
}
