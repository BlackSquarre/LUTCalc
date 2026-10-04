import Foundation

/// ACEScc encoding defined by the ACES 1.x logarithmic encoding specification.
/// Values are AP1 linear scene values; no LUT or sampled table is involved.
public enum ACESCCTransfer {
    public static let referenceURL = "https://docs.acescentral.com/encodings/acescc/"

    private static let low = pow(2.0, -15.0)
    private static let halfLow = pow(2.0, -16.0)
    private static let negativeCode = -0.3584474886
    private static let lowCode = (log2(low) + 9.72) / 17.52
    private static let maximumLinear = 65504.0
    private static let maximumCode = (log2(maximumLinear) + 9.72) / 17.52

    public static func encodeLinearAP1ToCC(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if linear <= 0 {
            result = negativeCode
        } else if linear < low {
            result = (log2(halfLow + linear * 0.5) + 9.72) / 17.52
        } else if linear < maximumLinear {
            result = (log2(linear) + 9.72) / 17.52
        } else {
            result = maximumCode
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeCCToLinearAP1(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if encoded < negativeCode {
            result = 0
        } else if encoded < lowCode {
            result = 2.0 * (exp2(encoded * 17.52 - 9.72) - halfLow)
        } else if encoded < maximumCode {
            result = exp2(encoded * 17.52 - 9.72)
        } else {
            result = maximumLinear
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static var publishedLowCode: Double { lowCode }
}
