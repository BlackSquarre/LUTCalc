import Foundation

/// SMPTE ST 2084 / ITU-R BT.2100 PQ transfer on normalized absolute luminance.
/// The scene value is normalized to 10,000 cd/m²; display peak and OOTF are
/// deliberately outside this scalar transfer and must be supplied by a display
/// pipeline before a screen preview is claimed.
public enum PQTransfer {
    public static let referenceURL = "https://www.itu.int/rec/R-REC-BT.2100/en"
    /// ST 2084 defines code values against an absolute 10,000 cd/m² range.
    public static let referencePeakNits = 10_000.0
    public static let m1 = 2610.0 / 16384.0
    public static let m2 = 2523.0 / 32.0
    public static let c1 = 3424.0 / 4096.0
    public static let c2 = 2413.0 / 128.0
    public static let c3 = 2392.0 / 128.0

    public static func encodeNormalizedLuminanceToData(_ luminance: Double) throws -> Double {
        guard luminance.isFinite else { throw NumericError.nonFinite }
        guard (0...1).contains(luminance) else { throw NumericError.invalidDomain }
        if luminance == 0 { return 0 }
        let powered = pow(luminance, m1)
        let result = pow((c1 + c2 * powered) / (1 + c3 * powered), m2)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToNormalizedLuminance(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        guard (0...1).contains(encoded) else { throw NumericError.invalidDomain }
        if encoded == 0 { return 0 }
        let powered = pow(encoded, 1 / m2)
        let numerator = max(powered - c1, 0)
        let denominator = c2 - c3 * powered
        guard denominator > 0 else { throw NumericError.invalidDomain }
        let result = pow(numerator / denominator, 1 / m1)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    /// Encodes absolute luminance in cd/m² using the ST 2084 reference range.
    /// Display peak, tone mapping and scene-to-display OOTF remain separate.
    public static func encodeAbsoluteLuminanceToData(_ nits: Double) throws -> Double {
        guard nits.isFinite else { throw NumericError.nonFinite }
        guard (0...referencePeakNits).contains(nits) else { throw NumericError.invalidDomain }
        return try encodeNormalizedLuminanceToData(nits / referencePeakNits)
    }

    /// Decodes a PQ code value to absolute luminance in cd/m².
    public static func decodeDataToAbsoluteLuminance(_ encoded: Double) throws -> Double {
        try decodeDataToNormalizedLuminance(encoded) * referencePeakNits
    }
}
