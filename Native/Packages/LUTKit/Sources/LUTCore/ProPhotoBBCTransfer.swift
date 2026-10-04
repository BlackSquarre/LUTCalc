import Foundation

/// ProPhoto / ROMM RGB transfer, using the published 16x toe and gamma 1.8.
/// The implementation is analytic and deliberately keeps extended signed data
/// in Double; negative values use the linear branch just as LUTCalc's source.
public enum ProPhotoTransfer {
    public static let referenceURL = "ITU-R BT.2380-0 §2.7 (RIMM-ROMM primaries); js/gamma.js:LUTGammaGam ProPhoto / ROMM registration"
    public static let gamma = 1.8
    public static let linearSlope = 16.0
    public static let linearCut = 1.0 / 512.0
    public static let encodedCut = 1.0 / 32.0
    public static let legacyDataScale = 0.85630498533724
    public static let legacyDataOffset = 0.06256109481916

    public static func encodeLinearToData(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result = linear >= linearCut ? pow(linear, 1.0 / gamma) : linear * linearSlope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLinear(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result = data >= encodedCut ? pow(data, gamma) : data / linearSlope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    /// LUTCalc's data-normalized wrapper around the ROMM transfer.
    public static func encodeLegacyToData(_ legacy: Double) throws -> Double {
        let legal = try encodeLinearToData(legacy)
        let data = legal * legacyDataScale + legacyDataOffset
        guard data.isFinite else { throw NumericError.nonFinite }
        return data
    }

    public static func decodeDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        return try decodeDataToLinear((data - legacyDataOffset) / legacyDataScale)
    }
}

/// The three BBC display gamma entries from LUTCalc's analytic LUTGammaBBCGam.
/// Parameters are retained explicitly so every branch is auditable against
/// the original registration and no sampled resource is needed.
public enum BBCGammaTransfer: String, CaseIterable, Sendable {
    case bbc04, bbc05, bbc06

    public static let dataScale = 0.85630498533724
    public static let dataOffset = 0.06256109481916

    public var exponent: Double {
        switch self {
        case .bbc04: 0.4
        case .bbc05: 0.5
        case .bbc06: 0.6
        }
    }

    public var slope: Double { 5.0 }

    public var offset: Double {
        switch self {
        case .bbc04: -0.02262
        case .bbc05: -0.01011
        case .bbc06: -0.00334
        }
    }

    public var linearCut: Double {
        switch self {
        case .bbc04: 0.037703
        case .bbc05: 0.020202
        case .bbc06: 0.008857
        }
    }

    public var encodedCut: Double {
        pow((linearCut + offset) / (1.0 + offset), exponent)
    }

    public func encodeLegacyToData(_ legacy: Double) throws -> Double {
        guard legacy.isFinite else { throw NumericError.nonFinite }
        // LUTGammaBBCGam uses a strict `>` for this forward boundary.
        let legal = legacy > linearCut
            ? pow((legacy + offset) / (1.0 + offset), exponent)
            : legacy * slope
        let result = legal * Self.dataScale + Self.dataOffset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let legal = (data - Self.dataOffset) / Self.dataScale
        // LUTGammaBBCGam uses `>=` for this inverse boundary.
        let result = legal >= encodedCut
            ? (1.0 + offset) * pow(legal, 1.0 / exponent) - offset
            : legal / slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
