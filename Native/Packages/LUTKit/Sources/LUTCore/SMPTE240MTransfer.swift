import Foundation

/// SMPTE 240M camera OETF, retained as an independent standard transfer.
/// Reference: ITU-R BT.2380-0, section 2.3 (historical SMPTE 240M parameters).
public enum SMPTE240MTransfer {
    public static let referenceURL = "https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2380-2015-PDF-E.pdf"
    private static let linearCutoff = 0.0228
    private static let encodedCutoff = 1.1115 * pow(0.0228, 0.45) - 0.1115

    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= linearCutoff ? 1.1115 * pow(value, 0.45) - 0.1115 : 4.0 * value
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= encodedCutoff ? pow((value + 0.1115) / 1.1115, 1.0 / 0.45) : value / 4.0
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
