import Foundation

/// Historical LUTCalc Rec.2020 12-bit registration from LUTGammaGam.
/// It is intentionally separate from the practical BT.2020 10-bit curve.
public enum Rec2020TwelveBitTransfer {
    public static let referenceSource = "js/gamma.js:LUTGammaGam Rec2020 12-bit registration"
    public static let dataScale = 0.85630498533724
    public static let dataOffset = 0.06256109481916
    public static let linearCut = 0.0181
    public static let legalCut = 0.08145

    public static func encodeLinearToLegal(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= linearCut ? 1.0993 * pow(value, 0.45) - 0.0993 : 4.5 * value
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeLegalToLinear(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= legalCut ? pow((value + 0.0993) / 1.0993, 1 / 0.45) : value / 4.5
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        let result = try encodeLinearToLegal(value) * dataScale + dataOffset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let legal = (value - dataOffset) / dataScale
        guard legal.isFinite else { throw NumericError.nonFinite }
        return try decodeLegalToLinear(legal)
    }
}
