import Foundation
import LUTCore

/// ICC PCS Lab encoding for user supplied profile data.
///
/// The conversion follows ICC.1:2022-05 §10.15/§10.16: 8-bit Lab stores
/// L* on 0...255 and a*/b* with an integer 128 offset; 16-bit Lab stores
/// L* on 0...65535 and scales a*/b* from the [-128, 127] PCS domain to the
/// unsigned 16-bit range. The PCS white is D50 and no gamut clipping is done.
public enum ICCLabPCS {
    public static let referenceURL = "ICC.1:2022-05 §10.15–§10.16"

    public enum Error: Swift.Error, Equatable, Sendable {
        case malformedEncoding
        case outsideDomain
        case nonFinite
        case numeric
    }

    public static func decode8(_ values: [UInt8]) throws -> CIELABColor {
        guard values.count == 3 else { throw Error.malformedEncoding }
        return try CIELABColor(
            lStar: Double(values[0]) / 255.0,
            aStar: Double(values[1]) - 128.0,
            bStar: Double(values[2]) - 128.0
        )
    }

    public static func encode8(_ lab: CIELABColor) throws -> [UInt8] {
        try validate(lab)
        let l = try quantize(lab.lStar * 255.0, lower: 0, upper: 255)
        let a = try quantize(lab.aStar + 128.0, lower: 0, upper: 255)
        let b = try quantize(lab.bStar + 128.0, lower: 0, upper: 255)
        return [UInt8(l), UInt8(a), UInt8(b)]
    }

    public static func decode16(_ values: [UInt16]) throws -> CIELABColor {
        guard values.count == 3 else { throw Error.malformedEncoding }
        return try CIELABColor(
            lStar: Double(values[0]) / 65535.0,
            aStar: Double(values[1]) * 255.0 / 65535.0 - 128.0,
            bStar: Double(values[2]) * 255.0 / 65535.0 - 128.0
        )
    }

    /// Decodes the continuous unsigned PCS representation used by ICC LUT
    /// pipelines before it is quantized to 8 or 16 bits.
    public static func decodeNormalized(_ values: [Double]) throws -> CIELABColor {
        guard values.count == 3 else { throw Error.malformedEncoding }
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw Error.outsideDomain
        }
        return try CIELABColor(
            lStar: values[0],
            aStar: values[1] * 255.0 - 128.0,
            bStar: values[2] * 255.0 - 128.0
        )
    }

    /// Encodes a CIELAB value into the continuous unsigned PCS representation
    /// used by ICC LUT pipelines.
    public static func encodeNormalized(_ lab: CIELABColor) throws -> [Double] {
        try validate(lab)
        return [lab.lStar, (lab.aStar + 128.0) / 255.0, (lab.bStar + 128.0) / 255.0]
    }

    public static func encode16(_ lab: CIELABColor) throws -> [UInt16] {
        try validate(lab)
        let l = try quantize(lab.lStar * 65535.0, lower: 0, upper: 65535)
        let a = try quantize((lab.aStar + 128.0) * 65535.0 / 255.0,
                             lower: 0, upper: 65535)
        let b = try quantize((lab.bStar + 128.0) * 65535.0 / 255.0,
                             lower: 0, upper: 65535)
        return [UInt16(l), UInt16(a), UInt16(b)]
    }

    public static func decode8ToXYZ(_ values: [UInt8]) throws -> XYZ64 {
        try decode8(values).toXYZ(white: .d50)
    }

    public static func decode16ToXYZ(_ values: [UInt16]) throws -> XYZ64 {
        try decode16(values).toXYZ(white: .d50)
    }

    public static func encode8FromXYZ(_ xyz: XYZ64) throws -> [UInt8] {
        try encode8(CIELABColorSpace.fromXYZ(xyz, white: .d50))
    }

    public static func encode16FromXYZ(_ xyz: XYZ64) throws -> [UInt16] {
        try encode16(CIELABColorSpace.fromXYZ(xyz, white: .d50))
    }

    private static func validate(_ lab: CIELABColor) throws {
        guard lab.lStar.isFinite, lab.aStar.isFinite, lab.bStar.isFinite else {
            throw Error.nonFinite
        }
        guard (0...1).contains(lab.lStar), (-128...127).contains(lab.aStar),
              (-128...127).contains(lab.bStar) else {
            throw Error.outsideDomain
        }
    }

    private static func quantize(_ value: Double, lower: Double, upper: Double) throws -> Int {
        guard value.isFinite else { throw Error.nonFinite }
        let rounded = value.rounded()
        guard rounded >= lower, rounded <= upper else { throw Error.outsideDomain }
        return Int(rounded)
    }
}
