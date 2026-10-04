import Foundation

/// Historical Canon C-Log scalar registration from LUTCalc.
///
/// The coefficients are preserved as an explicit legacy identity.  They are
/// not presented as a complete Canon CP IDT or as a public Canon C-Log
/// specification; those device and matrix semantics remain separate work.
public enum CanonCLogTransfer {
    public static let legacyReference =
        "js/gamma.js:LUTGammaLog Canon C-Log registration [0.3734467748,-0.0467265867,0.45310179472141,10.1596,10,0.1251224801564,1,0.00391002619746,-0.0452664]"

    private static let slope = 0.3734467748
    private static let intercept = -0.0467265867
    private static let logScale = 0.45310179472141
    private static let logInputScale = 10.1596
    private static let logOffset = 0.1251224801564
    private static let decodeCut = 0.00391002619746
    private static let encodeCut = -0.0452664

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= encodeCut
            ? logScale * Foundation.log10(value * logInputScale + 1.0) + logOffset
            : (value - intercept) / slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= decodeCut
            ? (Foundation.pow(10.0, (value - logOffset) / logScale) - 1.0) / logInputScale
            : slope * value + intercept
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
