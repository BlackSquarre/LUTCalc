import Foundation

public enum SLog3Transfer {
    public static let referenceURL =
        "https://www.sony.jp/ls-camera/knowledge/pdf/TechnicalSummary_for_S-Gamut3Cine_S-Gamut3_S-Log3_V1_00.pdf"

    private static let sonyCutScene = 0.01125000
    private static let sonyCutData = 171.2102946929 / 1023.0

    public static func encodeSonySceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result = scene >= sonyCutScene
            ? (420.0 + log10((scene + 0.01) / 0.19) * 261.5) / 1023.0
            : (scene * (171.2102946929 - 95.0) / sonyCutScene + 95.0) / 1023.0
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeSonyDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result = data >= sonyCutData
            ? pow(10.0, (data * 1023.0 - 420.0) / 261.5) * 0.19 - 0.01
            : (data * 1023.0 - 95.0) * sonyCutScene / (171.2102946929 - 95.0)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    // Historical LUTCalc LUTGammaLog coefficients are retained as an explicit analytic version.
    private static let legacyA = 0.1677922920
    private static let legacyB = -0.0155818840
    private static let legacyC = 0.2556207230
    private static let legacyD = 4.7368421060
    private static let legacyBase = 10.0000000000
    private static let legacyE = 0.4105571850
    private static let legacyF = 0.0526315790
    private static let legacyDecodeCut = 0.1673609920
    private static let legacyEncodeCut = 0.0125000000

    public static func encodeLegacyToData(_ legacyLinear: Double) throws -> Double {
        guard legacyLinear.isFinite else { throw NumericError.nonFinite }
        let result = legacyLinear >= legacyEncodeCut
            ? legacyC * log(legacyLinear * legacyD + legacyF) / log(legacyBase) + legacyE
            : (legacyLinear - legacyB) / legacyA
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeLegacyDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result = data >= legacyDecodeCut
            ? (pow(legacyBase, (data - legacyE) / legacyC) - legacyF) / legacyD
            : legacyA * data + legacyB
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
