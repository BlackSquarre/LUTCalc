import Foundation

/// Canon Log 3 analytic transfer as published by the ACES Canon CSC.
/// The published path uses scene-reference units and the Cinema Gamut
/// IDT's 0.9 scene scale. It intentionally does not stand in for Canon C-Log
/// or a camera-specific shoulder model.
public enum CanonCLog3Transfer {
    public static let referenceURL = "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/29b722bccd529460696a8382394504cae2e88419/canon/CSC.Canon.CLog3_CGamut_to_ACES.ctl"

    private static let publishedScale = 0.9
    private static let negativeCut = -0.014
    private static let positiveCut = 0.014
    private static let encodedNegativeCut = 0.097465473
    private static let encodedPositiveCut = 0.15277891
    private static let logarithmicSlope = 0.36726845
    private static let negativeOffset = 0.12783901
    private static let linearOffset = 0.12512219
    private static let positiveOffset = 0.12240537
    private static let linearSlope = 1.9754798
    private static let logarithmicScale = 14.98325

    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let linear = value / publishedScale
        let encoded: Double
        if linear < negativeCut {
            encoded = -logarithmicSlope * log10(1 - logarithmicScale * linear) + negativeOffset
        } else if linear <= positiveCut {
            encoded = linearSlope * linear + linearOffset
        } else {
            encoded = logarithmicSlope * log10(logarithmicScale * linear + 1) + positiveOffset
        }
        guard encoded.isFinite else { throw NumericError.nonFinite }
        return encoded
    }

    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let linear: Double
        if value < encodedNegativeCut {
            linear = -(pow(10, (negativeOffset - value) / logarithmicSlope) - 1) / logarithmicScale
        } else if value <= encodedPositiveCut {
            linear = (value - linearOffset) / linearSlope
        } else {
            linear = (pow(10, (value - positiveOffset) / logarithmicSlope) - 1) / logarithmicScale
        }
        let scene = publishedScale * linear
        guard scene.isFinite else { throw NumericError.nonFinite }
        return scene
    }
}
