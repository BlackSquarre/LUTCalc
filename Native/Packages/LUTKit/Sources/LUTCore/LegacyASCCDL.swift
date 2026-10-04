import Foundation

/// Retained LUTCalc semantics, not a claim of standard Rec.709 CDL behavior.
public enum ASCCDLAlgorithm: String, Codable, Sendable {
    case lutcalcWorkingLinearV1 = "lutcalc.asccdl-working-linear.v1"
}

public struct ASCCDLSettings: Equatable, Codable, Sendable {
    public let algorithm: ASCCDLAlgorithm
    public let enabled: Bool
    public let slope: RGB64
    public let offset: RGB64
    public let power: RGB64
    public let saturation: Double

    /// Legacy numeric entry has no hard slider bounds. Finite values are
    /// retained; singular/overflowing evaluations fail rather than become zero.
    public init(enabled: Bool = true, slope: RGB64 = try! RGB64(1,1,1),
                offset: RGB64 = try! RGB64(0,0,0), power: RGB64 = try! RGB64(1,1,1),
                saturation: Double = 1,
                algorithm: ASCCDLAlgorithm = .lutcalcWorkingLinearV1) throws {
        guard saturation.isFinite,
              (0..<3).allSatisfy({ slope[$0].isFinite && offset[$0].isFinite && power[$0].isFinite })
        else { throw NumericError.nonFinite }
        self.algorithm = algorithm
        self.enabled = enabled
        self.slope = slope
        self.offset = offset
        self.power = power
        self.saturation = saturation
    }

    private enum CodingKeys: String, CodingKey { case algorithm, enabled, slope, offset, power, saturation }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(enabled: c.decode(Bool.self, forKey: .enabled),
                      slope: c.decode(RGB64.self, forKey: .slope),
                      offset: c.decode(RGB64.self, forKey: .offset),
                      power: c.decode(RGB64.self, forKey: .power),
                      saturation: c.decode(Double.self, forKey: .saturation),
                      algorithm: c.decode(ASCCDLAlgorithm.self, forKey: .algorithm))
    }
}

/// Prepared immutable kernel. All samples remain Double; no sampled tables.
public struct LegacyASCCDL: Sendable {
    public let settings: ASCCDLSettings
    public let luma: RGB64

    public init(settings: ASCCDLSettings) throws {
        self.settings = settings
        let m = try ColorPrimaries.sonySGamut3Cine.rgbToXYZ().rowMajor
        luma = try RGB64(m[3], m[4], m[5])
    }

    public func evaluateLegacy(_ input: RGB64, applySaturation: Bool = true) throws -> RGB64 {
        guard settings.enabled else { return input }
        var q = [Double]()
        q.reserveCapacity(3)
        for c in 0..<3 {
            let v = input[c] * settings.slope[c] + settings.offset[c]
            guard v.isFinite else { throw NumericError.nonFinite }
            let powered = v < 0 ? v : pow(v, settings.power[c])
            guard powered.isFinite else { throw NumericError.nonFinite }
            q.append(powered)
        }
        guard applySaturation else { return try RGB64(q[0],q[1],q[2]) }
        let y = luma.r*q[0] + luma.g*q[1] + luma.b*q[2]
        guard y.isFinite else { throw NumericError.nonFinite }
        return try RGB64(y + settings.saturation*(q[0]-y),
                         y + settings.saturation*(q[1]-y),
                         y + settings.saturation*(q[2]-y))
    }

    public func evaluateScene(_ input: RGB64, applySaturation: Bool = true) throws -> RGB64 {
        guard settings.enabled else { return input }
        let legacy = try RGB64(LinearScale.sceneToLegacy(input.r),
                               LinearScale.sceneToLegacy(input.g),
                               LinearScale.sceneToLegacy(input.b))
        let result = try evaluateLegacy(legacy, applySaturation: applySaturation)
        return try RGB64(LinearScale.legacyToScene(result.r),
                         LinearScale.legacyToScene(result.g),
                         LinearScale.legacyToScene(result.b))
    }
}
