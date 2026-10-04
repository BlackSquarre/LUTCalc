import Foundation

/// Historical DJI X3 D-Log soft-clip registration from LUTCalc.
public enum DJIX3DLogTransfer {
    public static let legacyReference = "js/gamma.js:LUTGammaLogClip DJI X3 DLog [0.188272019,-0.011778504,0.473218054,6.086793376,10,0.419294419,0.169033387,0.095812746,0.00625,0.902863937,1.59668525,22.90700861,-17.39462704]"
    private static let slope = 0.188272019
    private static let intercept = -0.011778504
    private static let logScale = 0.473218054
    private static let inputScale = 6.086793376
    private static let logBase = 10.0
    private static let logOffset = 0.419294419
    private static let inputOffset = 0.169033387
    private static let decodeLogCut = 0.095812746
    private static let encodeLogCut = 0.00625
    private static let decodeShoulderCut = 0.902863937
    private static let encodeShoulderCut = 1.59668525
    private static let shoulderScale = 22.90700861
    private static let shoulderOffset = -17.39462704

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value >= encodeShoulderCut {
            result = (Foundation.log(value / 0.2) / Foundation.log(2) - shoulderOffset) / shoulderScale
        } else if value >= encodeLogCut {
            result = logScale * Foundation.log(value * inputScale + inputOffset) / Foundation.log(logBase) + logOffset
        } else {
            result = (value - intercept) / slope
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value >= decodeShoulderCut {
            result = Foundation.pow(2, shoulderScale * value + shoulderOffset) * 0.2
        } else if value >= decodeLogCut {
            result = (Foundation.pow(logBase, (value - logOffset) / logScale) - inputOffset) / inputScale
        } else {
            result = slope * value + intercept
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
