import Foundation

public enum ACESCCTTransfer {
    public static let referenceURL = "https://docs.acescentral.com/encodings/acescct/"

    private static let toeSlope = 10.5402377416545
    private static let toeOffset = 0.0729055341958355
    private static let linearCut = 0.0078125
    private static let encodedCut = 0.155251141552511
    private static let maximumLinear = 65504.0
    private static let maximumEncoded = (log2(maximumLinear) + 9.72) / 17.52

    public static func encodeLinearAP1ToCCT(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if linear <= linearCut {
            result = toeSlope * linear + toeOffset
        } else {
            guard linear > 0 else { throw NumericError.invalidDomain }
            result = (log2(linear) + 9.72) / 17.52
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeCCTToLinearAP1(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if encoded <= encodedCut {
            result = (encoded - toeOffset) / toeSlope
        } else if encoded < maximumEncoded {
            result = exp2(encoded * 17.52 - 9.72)
        } else {
            result = maximumLinear
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
