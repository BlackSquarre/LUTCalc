import Foundation

/// Historical DaVinci Intermediate scalar registration from LUTCalc.
public enum DaVinciIntermediateTransfer {
    public static let legacyReference = "js/gamma.js:LUTGammaDaVinci DaVinci Intermediate (a=0.0075,b=7,c=0.07329248,m=10.44426855,lin_cut=0.00262409,log_cut=0.02740668,rescale=1/0.9)"
    private static let a = 0.0075
    private static let b = 7.0
    private static let c = 0.07329248
    private static let m = 10.44426855
    private static let linearCut = 0.00262409
    private static let logCut = 0.02740668
    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let x = value * 0.9
        let legal = x > linearCut ? (Foundation.log2(x + a) + b) * c : x * m
        let result = legal * 0.85630498533724 + 0.06256109481916
        guard result.isFinite else { throw NumericError.nonFinite }; return result
    }
    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let legal = (value - 0.06256109481916) / 0.85630498533724
        let result = (legal >= logCut ? Foundation.pow(2, legal / c - b) - a : legal / m) / 0.9
        guard result.isFinite else { throw NumericError.nonFinite }; return result
    }
}
