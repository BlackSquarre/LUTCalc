import Foundation

/// A traceable piecewise power transfer used by the published LUTCalc
/// `LUTGammaGam` family. This is an analytic algorithm, not a sampled LUT.
public struct ParameterizedGammaTransfer: Equatable, Sendable {
    public static let familyID = "gamma.parameterized.v1"
    public static let referenceSource = "js/gamma.js:LUTGammaGam"

    public let exponent: Double
    public let linearSlope: Double
    public let offset: Double
    public let linearCut: Double
    public let encodedCut: Double

    public init(exponent: Double, linearSlope: Double, offset: Double,
                linearCut: Double, encodedCut: Double? = nil) throws {
        guard exponent.isFinite, linearSlope.isFinite, offset.isFinite,
              linearCut.isFinite, exponent > 0, linearSlope > 0,
              offset > -1, linearCut >= 0 else {
            throw NumericError.invalidDomain
        }
        let resolvedEncodedCut = encodedCut ?? linearSlope * linearCut
        guard resolvedEncodedCut.isFinite, resolvedEncodedCut >= 0 else {
            throw NumericError.invalidDomain
        }
        self.exponent = exponent
        self.linearSlope = linearSlope
        self.offset = offset
        self.linearCut = linearCut
        self.encodedCut = resolvedEncodedCut
    }

    public func encodeLegacyToLegal(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value >= linearCut {
            result = (1 + offset) * pow(value, 1 / exponent) - offset
        } else {
            result = linearSlope * value
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeLegalToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if value >= encodedCut {
            result = pow((value + offset) / (1 + offset), exponent)
        } else {
            result = value / linearSlope
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}

/// Persistable parameters for the analytic LUTGammaGam family.
/// The values are kept as Double fields so a project can reproduce the
/// transfer without referring to a sampled table or a web runtime.
public struct ParameterizedGammaSettings: Codable, Equatable, Sendable {
    public let exponent: Double
    public let linearSlope: Double
    public let offset: Double
    public let linearCut: Double
    public let encodedCut: Double?

    public init(exponent: Double, linearSlope: Double, offset: Double,
                linearCut: Double, encodedCut: Double? = nil) throws {
        let transfer = try ParameterizedGammaTransfer(
            exponent: exponent,
            linearSlope: linearSlope,
            offset: offset,
            linearCut: linearCut,
            encodedCut: encodedCut
        )
        self.exponent = transfer.exponent
        self.linearSlope = transfer.linearSlope
        self.offset = transfer.offset
        self.linearCut = transfer.linearCut
        self.encodedCut = encodedCut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            exponent: try container.decode(Double.self, forKey: .exponent),
            linearSlope: try container.decode(Double.self, forKey: .linearSlope),
            offset: try container.decode(Double.self, forKey: .offset),
            linearCut: try container.decode(Double.self, forKey: .linearCut),
            encodedCut: try container.decodeIfPresent(Double.self, forKey: .encodedCut)
        )
    }

    public func makeTransfer() throws -> ParameterizedGammaTransfer {
        try ParameterizedGammaTransfer(
            exponent: exponent,
            linearSlope: linearSlope,
            offset: offset,
            linearCut: linearCut,
            encodedCut: encodedCut
        )
    }

    private enum CodingKeys: String, CodingKey {
        case exponent, linearSlope, offset, linearCut, encodedCut
    }
}
