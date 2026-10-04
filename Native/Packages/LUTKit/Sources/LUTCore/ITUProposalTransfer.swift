import Foundation

/// Analytic LUTCalc registrations for the historical ITU Proposal variants.
/// This identity records the old implementation and does not claim standards
/// conformance beyond its frozen parameters and branches.
public struct ITUProposalTransfer: Equatable, Sendable {
    public static let referenceSource = "js/gamma.js:LUTGammaITUProp registrations"
    public static let dataScale = 0.85630498533724
    public static let dataOffset = 0.06256109481916

    public let kneeLinear: Double
    public let shoulderSlope: Double
    public let shoulderOffset: Double
    public let kneeEncoded: Double

    public init(kneeLinear: Double) throws {
        guard kneeLinear.isFinite, kneeLinear > 0.0181 else {
            throw NumericError.invalidDomain
        }
        let shoulderSlope = 0.45 * 1.0993 * Foundation.pow(kneeLinear, 0.45)
        let shoulderOffset = 1.0993 * Foundation.pow(kneeLinear, 0.45)
            * (1 - 0.45 * Foundation.log(kneeLinear)) - 0.0993
        let kneeEncoded = 1.0993 * Foundation.pow(kneeLinear, 0.45) - 0.0993
        guard shoulderSlope.isFinite, shoulderOffset.isFinite, kneeEncoded.isFinite else {
            throw NumericError.nonFinite
        }
        self.kneeLinear = kneeLinear
        self.shoulderSlope = shoulderSlope
        self.shoulderOffset = shoulderOffset
        self.kneeEncoded = kneeEncoded
    }

    public static let percent400: ITUProposalTransfer = {
        try! ITUProposalTransfer(kneeLinear: 0.12314858)
    }()

    public static let percent800: ITUProposalTransfer = {
        try! ITUProposalTransfer(kneeLinear: 0.083822216783)
    }()

    public func encodeLinearToLegal(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value > kneeLinear {
            result = shoulderSlope * Foundation.log(value) + shoulderOffset
        } else if value >= 0.0181 {
            result = 1.0993 * Foundation.pow(value, 0.45) - 0.0993
        } else {
            result = 4.5 * value
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeLegalToLinear(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value > kneeEncoded {
            result = Foundation.exp((value - shoulderOffset) / shoulderSlope)
        } else if value >= 0.08145 {
            result = Foundation.pow((value + 0.0993) / 1.0993, 1 / 0.45)
        } else {
            result = value / 4.5
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
