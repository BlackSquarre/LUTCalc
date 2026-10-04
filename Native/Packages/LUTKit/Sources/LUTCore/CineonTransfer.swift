import Foundation

/// Kodak Cineon encoding and the historical LUTCalc-compatible toe variant.
///
/// The published Cineon equation uses a 95 code black offset and a 685 code
/// reference white. LUTCalc's older implementation adds a linear toe below
/// the derived black point; it is kept as a separate transfer identity.
public enum CineonTransfer {
    public static let referenceURL =
        "https://github.com/imageworks/OpenColorIO-Configs/blob/c0ff0e96574e823606a81e62e3867d9d8ba238db/nuke-default/make.py#L161 Cineon equation; independent Colour Science implementation: https://github.com/colour-science/colour/blob/ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5/colour/models/rgb/transfer_functions/cineon.py"
    public static let legacyReference =
        "js/gamma.js:LUTGammaCineon (cv=1023, bp=95, wp=685, nGamma=0.6, cv2d=0.002)"

    private static let codeValue = 1023.0
    private static let blackCode = 95.0
    private static let whiteCode = 685.0
    private static let blackOffset = Foundation.pow(10.0, (blackCode - whiteCode) / 300.0)

    private static let legacyMul = 1.0 / 300.0
    private static let legacyBlack = blackOffset
    private static let legacyDenominator = 0.9 * (1.0 - legacyBlack)
    private static let legacyP0 =
        (Foundation.pow(10.0, -whiteCode * legacyMul) - legacyBlack) / legacyDenominator
    private static let legacyD0 = {
        let at = (Foundation.pow(10.0, (0.0001 * codeValue - whiteCode) * legacyMul) - legacyBlack) /
            legacyDenominator
        return (at - legacyP0) / 0.0001
    }()

    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        guard value * (1.0 - blackOffset) + blackOffset > 0 else {
            throw NumericError.invalidDomain
        }
        let result = (whiteCode + 300.0 * Foundation.log10(value * (1.0 - blackOffset) + blackOffset)) /
            codeValue
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = (Foundation.pow(10.0, (codeValue * value - whiteCode) / 300.0) - blackOffset) /
            (1.0 - blackOffset)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value < legacyP0 {
            result = (value - legacyP0) / legacyD0
        } else {
            guard value * legacyDenominator + legacyBlack > 0 else {
                throw NumericError.invalidDomain
            }
            result = (Foundation.log10(value * legacyDenominator + legacyBlack) / legacyMul + whiteCode) /
                codeValue
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value < 0 {
            result = value * legacyD0 + legacyP0
        } else {
            result = (Foundation.pow(10.0, (value * codeValue - whiteCode) * legacyMul) - legacyBlack) /
                legacyDenominator
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
