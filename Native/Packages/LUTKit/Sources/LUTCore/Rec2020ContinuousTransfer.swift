import Foundation

/// Continuous BT.2020 OETF from BT.2020-2, distinct from practical 10-bit constants.
public enum Rec2020ContinuousTransfer {
    public static let referenceURL = "https://www.itu.int/rec/R-REC-BT.2020"
    public static let alpha = 1.09929682680944
    public static let beta = 0.018053968510807
    public static let slope = 4.5
    public static let encodedBeta = alpha * pow(beta, 0.45) - (alpha - 1.0)
    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= beta ? alpha * pow(value, 0.45) - (alpha - 1.0) : slope * value
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= encodedBeta ? pow((value + (alpha - 1.0)) / alpha, 1.0 / 0.45) : value / slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
