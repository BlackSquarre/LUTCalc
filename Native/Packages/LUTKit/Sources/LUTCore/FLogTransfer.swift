import Foundation

/// Historical Fujifilm F-Log LUTCalc registration.
///
/// This preserves the old nine-parameter LUTGammaLog path as a legacy
/// identity. It does not claim the complete published Fujifilm camera model.
public enum FLogTransfer {
    public static let legacyReference =
        "js/gamma.js:LUTGammaLog Fujifilm F-Log registration [0.1144737,-0.010630486,0.344676,0.5000004,10,0.790453,0.009468,0.100537775,0.000988889]"

    private static let slope = 0.1144737
    private static let intercept = -0.010630486
    private static let logScale = 0.344676
    private static let logInputScale = 0.5000004
    private static let logOffset = 0.790453
    private static let logInputOffset = 0.009468
    private static let decodeCut = 0.100537775
    private static let encodeCut = 0.000988889

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
