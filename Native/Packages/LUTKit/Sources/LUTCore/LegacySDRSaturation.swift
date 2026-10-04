import Foundation

/// Retained LUTCalc SDR correction, not an HLG OOTF or display transform.
public enum SDRSaturationAlgorithm: String, Codable, Sendable {
    case lutcalcOutputLinearV1 = "lutcalc.sdr-saturation-output-linear.v1"
}

public struct SDRSaturationSettings: Equatable, Codable, Sendable {
    public let algorithm: SDRSaturationAlgorithm
    public let enabled: Bool
    public let gamma: Double

    public init(enabled: Bool = true, gamma: Double = 1.2,
                algorithm: SDRSaturationAlgorithm = .lutcalcOutputLinearV1) throws {
        // The retained user parameter has hard numeric bounds, unlike ASC-CDL.
        guard gamma.isFinite, (1...2).contains(gamma) else { throw NumericError.invalidDomain }
        self.algorithm = algorithm
        self.enabled = enabled
        self.gamma = gamma
    }

    private enum CodingKeys: String, CodingKey { case algorithm, enabled, gamma }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(enabled: c.decode(Bool.self, forKey: .enabled),
                      gamma: c.decode(Double.self, forKey: .gamma),
                      algorithm: c.decode(SDRSaturationAlgorithm.self, forKey: .algorithm))
    }
}

/// Output-primary Y weights are computed analytically, with no sampled table.
public struct LegacySDRSaturation: Sendable {
    public let settings: SDRSaturationSettings
    public let luma: RGB64
    private let db: Double
    private let dr: Double

    public init(settings: SDRSaturationSettings, outputPrimaries: ColorPrimaries) throws {
        self.settings = settings
        let m = try outputPrimaries.rgbToXYZ().rowMajor
        luma = try RGB64(m[3],m[4],m[5])
        db = 2 * (1-luma.b)
        dr = 2 * (1-luma.r)
        guard db != 0, dr != 0, luma.g != 0 else { throw MatrixError.invalidConeResponse }
    }

    public func evaluateLegacy(_ input: RGB64) throws -> RGB64 {
        try evaluate(input).output
    }

    private func evaluate(_ input: RGB64) throws -> (output: RGB64, bypass: Bool) {
        guard settings.enabled else { return (input,true) }
        let inverseGamma = 1/settings.gamma
        func encoded(_ value: Double) throws -> Double {
            let v = value/12
            let q = value < 0 ? v : pow(v,inverseGamma)
            guard q.isFinite else { throw NumericError.nonFinite }
            return q
        }
        let r = try encoded(input.r), g = try encoded(input.g), b = try encoded(input.b)
        let y = luma.r*r + luma.g*g + luma.b*b
        guard y.isFinite else { throw NumericError.nonFinite }
        // The old function leaves the original linear sample untouched here.
        guard y > 0 else { return (input,true) }
        let pb = (b-y)/db, pr = (r-y)/dr
        let linearY = pow(y,settings.gamma)
        guard linearY.isFinite else { throw NumericError.nonFinite }
        let outR = pr*dr + linearY, outB = pb*db + linearY
        let outG = (linearY-luma.r*outR-luma.b*outB)/luma.g
        return (try RGB64(outR*12,outG*12,outB*12),false)
    }

    public func evaluateScene(_ input: RGB64) throws -> RGB64 {
        guard settings.enabled else { return input }
        let legacy = try RGB64(LinearScale.sceneToLegacy(input.r),
                               LinearScale.sceneToLegacy(input.g),
                               LinearScale.sceneToLegacy(input.b))
        let evaluated = try evaluate(legacy)
        // Preserve the bypass branch exactly, including negative zero.
        if evaluated.bypass { return input }
        let result = evaluated.output
        return try RGB64(LinearScale.legacyToScene(result.r),
                         LinearScale.legacyToScene(result.g),
                         LinearScale.legacyToScene(result.b))
    }
}
