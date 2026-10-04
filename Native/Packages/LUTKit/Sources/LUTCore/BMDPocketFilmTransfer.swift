import Foundation

/// Historical Blackmagic Pocket Film analytic registration.
///
/// This is the old nine-parameter LUTCalc curve. It is deliberately exposed
/// as a legacy identity only; the camera catalog's Passthrough gamut does not
/// provide enough evidence to invent a Blackmagic input colour space.
public enum BMDPocketFilmTransfer {
    public static let legacyReference =
        "js/gamma.js:LUTGammaLog BMD Pocket Film registration [0.195367159/0.9,-0.014273567/0.9,0.36274758,1.05345192*0.9,10,0.63659829,0.027616437,0.096214896,0.004523664*0.9]"

    private static let slope = 0.195367159 / 0.9
    private static let intercept = -0.014273567 / 0.9
    private static let logScale = 0.36274758
    private static let logInputScale = 1.05345192 * 0.9
    private static let logOffset = 0.63659829
    private static let logInputOffset = 0.027616437
    private static let decodeCut = 0.096214896
    private static let encodeCut = 0.004523664 * 0.9

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= encodeCut
            ? logScale * Foundation.log10(value * logInputScale + logInputOffset) + logOffset
            : (value - intercept) / slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= decodeCut
            ? (Foundation.pow(10.0, (value - logOffset) / logScale) - logInputOffset) / logInputScale
            : slope * value + intercept
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
