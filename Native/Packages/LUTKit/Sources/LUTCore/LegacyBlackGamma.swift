import Foundation

public enum BlackGammaAlgorithm: String, Codable, Sendable {
    case lutcalcOutputEncodedV1 = "lutcalc.black-gamma-output-encoded.v1"
    case lutcalcOutputEncodedStableV1 = "lutcalc.black-gamma-output-encoded-stable.v1"
}

public struct BlackGammaSettings: Equatable, Codable, Sendable {
    public let algorithm: BlackGammaAlgorithm
    public let enabled: Bool
    public let upperStops: Double
    public let featherStops: Double
    public let power: Double

    public init(enabled: Bool = true, upperStops: Double = -1.5, featherStops: Double = 2,
                power: Double = 1, algorithm: BlackGammaAlgorithm = .lutcalcOutputEncodedStableV1) throws {
        guard upperStops.isFinite, (-9...2).contains(upperStops),
              featherStops.isFinite, (0...9).contains(featherStops),
              power.isFinite, (0.01...10).contains(power) else { throw NumericError.invalidDomain }
        self.algorithm = algorithm
        self.enabled = enabled
        self.upperStops = upperStops
        self.featherStops = featherStops
        self.power = power
    }

    private enum CodingKeys: String, CodingKey { case algorithm, enabled, upperStops, featherStops, power }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),
                      upperStops:c.decode(Double.self,forKey:.upperStops),
                      featherStops:c.decode(Double.self,forKey:.featherStops),
                      power:c.decode(Double.self,forKey:.power),
                      algorithm:c.decode(BlackGammaAlgorithm.self,forKey:.algorithm))
    }
}

/// Anchors are encoded outputs, not scene stops. No clipping or sample table.
public struct LegacyBlackGamma: Sendable {
    public let settings: BlackGammaSettings
    public let black: Double
    public let lower: Double
    public let upper: Double
    private let radius: Double
    private let feather: Double

    public init(settings: BlackGammaSettings, black: Double, lower: Double, upper: Double) throws {
        guard black.isFinite, lower.isFinite, upper.isFinite,
              (upper-black).isFinite, (upper-lower).isFinite else { throw NumericError.nonFinite }
        self.settings=settings
        self.black=black
        self.lower=lower
        self.upper=upper
        radius=upper-black
        feather=upper-lower
    }

    public func evaluate(_ input: Double) throws -> Double {
        guard input.isFinite else { throw NumericError.nonFinite }
        guard settings.enabled, input>black, input<=upper else { return input }
        let delta=input-black
        let ratio=delta/radius
        let curved:Double
        if settings.algorithm == .lutcalcOutputEncodedStableV1 {
            if settings.power == 1 { return input }
            // Avoid rounding the subnormal ratio before a fractional power.
            // The stable form is the same continuous formula, independently
            // checked against Decimal; it has a distinct version identity.
            if ratio < Double.leastNormalMagnitude {
                curved=exp(settings.power*log(delta)+(1-settings.power)*log(radius))+black
            }else{curved=pow(ratio,settings.power)*radius+black}
        }else{curved=pow(ratio,settings.power)*radius+black}
        var output=curved
        if input>lower && input>curved {
            let t=(input-lower)/feather
            let squared=t*t
            output=squared*input+(1-squared)*curved
        }
        guard output.isFinite else { throw NumericError.nonFinite }
        return output
    }

    public func evaluate(_ input: RGB64) throws -> RGB64 {
        try RGB64(evaluate(input.r),evaluate(input.g),evaluate(input.b))
    }
}
