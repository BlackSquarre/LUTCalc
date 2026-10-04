import Foundation

/// BBC White Paper 283's analytic transfer as registered by the legacy
/// LUTCalc implementation. The native entry is intentionally labelled as
/// legacy compatibility until an independent copy of WHP283 is archived.
public struct BBCWHP283Transfer: Equatable, Sendable {
    public static let referenceSource = "js/gamma.js:LUTGammaBBC283 (BBC WHP283 registration)"
    public static let dataScale = 0.85630498533724
    public static let dataOffset = 0.06256109481916

    public let m: Double
    public let n: Double
    public let r: Double
    public let e: Double
    public let systemGamma: Double

    public init(m: Double, systemGamma: Double = 1) throws {
        guard m.isFinite, m > 0, systemGamma.isFinite, systemGamma > 0 else {
            throw NumericError.invalidDomain
        }
        let root = Foundation.sqrt(m)
        let n = root / 2
        let r = root * (1 - Foundation.log(root))
        guard root.isFinite, n.isFinite, r.isFinite else { throw NumericError.nonFinite }
        self.m = m
        self.n = n
        self.r = r
        self.e = root
        self.systemGamma = systemGamma
    }

    public static let percent400: BBCWHP283Transfer = {
        try! BBCWHP283Transfer(m: 0.139401137752)
    }()

    public static let percent800: BBCWHP283Transfer = {
        try! BBCWHP283Transfer(m: 0.097401889128)
    }()

    public func encodeLinearToLegal(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        // WHP283 uses strict `>` at m and 0.
        if value > m {
            result = n * Foundation.log(value) + r
        } else if value > 0 {
            result = Foundation.sqrt(value)
        } else {
            result = 0
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeLegalToLinear(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        // WHP283 uses strict `>` at e; the lower branch is y^(2s).
        if value > e {
            result = Foundation.exp(systemGamma * (value - r) / n)
        } else {
            result = Foundation.pow(value, 2 * systemGamma)
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func encodeLegacyToData(_ value: Double) throws -> Double {
        let legal = try encodeLinearToLegal(value)
        let result = legal * Self.dataScale + Self.dataOffset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let legal = (value - Self.dataOffset) / Self.dataScale
        guard legal.isFinite else { throw NumericError.nonFinite }
        return try decodeLegalToLinear(legal)
    }
}
