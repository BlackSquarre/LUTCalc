import Foundation

/// ITU-R BT.2100-3 Table 5 reference HLG OETF and its inverse.
/// This is the scene-linear transfer only; OOTF/display parameters are separate.
public enum HLGTransfer {
    public static let referenceURL = "https://www.itu.int/rec/R-REC-BT.2100/en"
    public static let a = 0.17883277
    public static let b = 0.28466892
    public static let c = 0.5 - a * log(4.0 * a)
    private static let breakpoint = 1.0 / 12.0

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        guard scene >= 0 else { throw NumericError.invalidDomain }
        let result = scene <= breakpoint
            ? sqrt(3.0 * scene)
            : a * log(12.0 * scene - b) + c
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        guard encoded >= 0 else { throw NumericError.invalidDomain }
        let result = encoded <= 0.5
            ? (encoded * encoded) / 3.0
            : (exp((encoded - c) / a) + b) / 12.0
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
