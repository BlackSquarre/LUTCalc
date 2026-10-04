import Foundation

/// Analytic Nikon N-Log transfer for user and camera-profile data.
///
/// The curve uses a cubic toe and a logarithmic shoulder. Values use
/// normalized data code units without implicit clamping; legal-range conversion is a separate
/// output-code-unit boundary.
public enum NikonNLogTransfer {
    public static let referenceURL =
        "Nikon N-Log Specification Document v1.0.0 (2018), section 2, https://download.nikonimglib.com/archive3/hDCmK00m9JDI03RPruD74xpoU905/N-Log_Specification_(En)01.pdf; independent Colour Science implementation cross-check: https://github.com/colour-science/colour/blob/ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5/colour/models/rgb/transfer_functions/nikon_n_log.py"

    // The legacy methods accept/return LUTCalc linear values (middle grey 0.2).
    // TransformPlan adapts these once at the scene-reflectance boundary.
    public static let legacyReference = "js/gamma.js:LUTGammaNLog, cubic coefficient 650.1864339, cutoff 451.7887494, legacy linear scale 0.9"

    private static let sceneScale = 0.9
    private static let toeCut = 0.328
    private static let toeOffset = 0.0075
    private static let toeScale = 650.1864339 / 1023.0
    private static let logScale = 150.0
    private static let logOffset = 619.0
    private static let logCut = 451.7887494 / 1023.0

    // Official reflected-light formula, including the published rounded
    // branch gap. Never adjust Nikon's constants to create an exact inverse.
    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result = scene < 0.328
            ? Foundation.cbrt(scene + 0.0075) * 650.0 / 1023.0
            : (150.0 * Foundation.log(scene) + 619.0) / 1023.0
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result = data < 452.0 / 1023.0
            ? Foundation.pow(data * 1023.0 / 650.0, 3.0) - 0.0075
            : Foundation.exp((data * 1023.0 - 619.0) / 150.0)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func encodeLegacyToData(_ legacy: Double) throws -> Double {
        guard legacy.isFinite else { throw NumericError.nonFinite }
        let scaled = legacy * sceneScale
        let result: Double
        if scaled >= toeCut {
            guard scaled > 0 else { throw NumericError.invalidDomain }
            result = (logScale * Foundation.log(scaled) + logOffset) / 1023.0
        } else {
            result = signedCubeRoot(scaled + toeOffset) * toeScale
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let encoded = data >= logCut
            ? Foundation.exp((data * 1023.0 - logOffset) / logScale)
            : Foundation.pow(data / toeScale, 3.0) - toeOffset
        let result = encoded / sceneScale
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    private static func signedCubeRoot(_ value: Double) -> Double {
        value < 0 ? -Foundation.pow(-value, 1.0 / 3.0) : Foundation.pow(value, 1.0 / 3.0)
    }
}
