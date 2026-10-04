import Foundation

/// Historical RED Log3G10 analytic registration from LUTCalc.
///
/// The curve is kept as a distinct legacy identity. The 0.9 linear boundary
/// and LUTCalc legal-normalized data wrapper are part of this registration;
/// RED camera gamut and IPP2 output rendering remain separate concerns.
public enum REDLog3G10Transfer {
    public static let legacyReference =
        "js/gamma.js:LUTGammaLogLog RED Log3G10 registration [0.224282,155.975327,0.01]"

    private static let slope = 0.224282
    private static let inputScale = 155.975327
    private static let inputOffset = 0.01
    private static let legacyScale = 0.9
    private static let legalScale = 0.85630498533724
    private static let legalOffset = 0.06256109481916

    public static func encodeLegacyToData(_ legacy: Double) throws -> Double {
        guard legacy.isFinite else { throw NumericError.nonFinite }
        let shifted = legacy * legacyScale + inputOffset
        let logValue: Double
        if shifted < 0 {
            guard (-shifted * inputScale + 1).isFinite else { throw NumericError.nonFinite }
            logValue = -slope * Foundation.log10(-shifted * inputScale + 1)
        } else {
            guard (shifted * inputScale + 1).isFinite else { throw NumericError.nonFinite }
            logValue = slope * Foundation.log10(shifted * inputScale + 1)
        }
        let result = logValue * legalScale + legalOffset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let logValue = (data - legalOffset) / legalScale
        let magnitude = Foundation.pow(10.0, abs(logValue) / slope)
        let linear = logValue < 0
            ? ((1 - magnitude) / inputScale - inputOffset) / legacyScale
            : ((magnitude - 1) / inputScale - inputOffset) / legacyScale
        guard linear.isFinite else { throw NumericError.nonFinite }
        return linear
    }

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        try encodeLegacyToData(scene)
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        try decodeDataToLegacy(data)
    }
}
