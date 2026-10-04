import Foundation

/// The practical 10-bit OETF constants specified by ITU-R BT.2020-2.
/// This is kept separate from the historical LUTCalc Rec.2020 12-bit curve:
/// BT.2020-2 assigns alpha=1.099 and beta=0.018 to 10-bit systems, while the
/// 12-bit practical values are alpha=1.0993 and beta=0.0181.
public enum Rec2020TenBitTransfer {
    public static let referenceURL = "https://www.itu.int/rec/R-REC-BT.2020"
    public static let alpha = 1.099
    public static let beta = 0.018
    public static let slope = 4.5
    public static let encodedBeta = 0.081

    public static func encodeSceneToData(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result = linear >= beta
            ? alpha * pow(linear, 0.45) - (alpha - 1)
            : slope * linear
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result = encoded >= encodedBeta
            ? pow((encoded + (alpha - 1)) / alpha, 1 / 0.45)
            : encoded / slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
