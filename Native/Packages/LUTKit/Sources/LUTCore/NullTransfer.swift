import Foundation

/// Historical LUTCalc Null transfer: linear legacy signal with the shared
/// Legal/Data wrapper used by the old gamma engine.
public enum NullTransfer {
    public static let legacyReference =
        "js/gamma.js:LUTGammaNull linToData/linFromData"
    private static let scale = 0.85630498533724
    private static let offset = 0.06256109481916

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value * scale + offset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = (value - offset) / scale
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
