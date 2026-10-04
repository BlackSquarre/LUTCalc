import Foundation

public enum Rec709Transfer {
    public static let referenceURL = "https://www.itu.int/dms_pubrec/itu-r/rec/bt/r-rec-bt.709-6-201506-i%21%21pdf-e.pdf"

    public static func encodeLegacy(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result = linear >= 0.018
            ? 1.099 * pow(linear, 0.45) - 0.099
            : 4.5 * linear
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeLegacy(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result = encoded >= 0.081
            ? pow((encoded + 0.099) / 1.099, 1 / 0.45)
            : encoded / 4.5
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
