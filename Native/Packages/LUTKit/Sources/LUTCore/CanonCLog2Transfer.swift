import Foundation

/// Canon Log 2 analytic transfer as published by the ACES Canon CSC.
/// The published path uses scene-reference units; the legacy path retains
/// LUTCalc's historical linear-reference coefficients independently.
public enum CanonCLog2Transfer {
    public static let referenceURL = "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/29b722bccd529460696a8382394504cae2e88419/canon/CSC.Canon.CLog2_CGamut_to_ACES.ctl"

    private static let slope = 0.24136077
    private static let publishedScale = 0.9
    private static let publishedConstant = 87.099375
    private static let legacyConstant = 87.09937546
    private static let offset = 0.092864125
    private static let legacyNegativeCut = -0.006747091156
    private static let legacyNegativeSlope = 0.045164984

    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let linear = value / publishedScale
        let encoded = linear < 0
            ? -slope * log10(1 - publishedConstant * linear) + offset
            : slope * log10(publishedConstant * linear + 1) + offset
        guard encoded.isFinite else { throw NumericError.nonFinite }
        return encoded
    }

    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let linear = value < offset
            ? -(pow(10, (offset - value) / slope) - 1) / publishedConstant
            : (pow(10, (value - offset) / slope) - 1) / publishedConstant
        let scene = publishedScale * linear
        guard scene.isFinite else { throw NumericError.nonFinite }
        return scene
    }

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let encoded = value >= legacyNegativeCut
            ? slope * log10(legacyConstant * value + 1) + offset
            : (value - legacyNegativeCut) / legacyNegativeSlope
        guard encoded.isFinite else { throw NumericError.nonFinite }
        return encoded
    }

    public static func decodeLegacyDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        // Preserve the legacy zero-code identity used by the catalog smoke
        // contract; the rounded historical constants otherwise leave a tiny
        // negative residue at exactly zero.
        if value == 0 { return 0 }
        let linear = value >= 0
            ? (pow(10, (value - offset) / slope) - 1) / legacyConstant
            : legacyNegativeSlope * value + legacyNegativeCut
        guard linear.isFinite else { throw NumericError.nonFinite }
        return linear
    }
}
