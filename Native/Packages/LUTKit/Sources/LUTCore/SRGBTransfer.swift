import Foundation

public enum SRGBVariant: String, Codable, Sendable {
    case w3cExtended = "srgb.w3c-extended.v1"
    case lutcalcLegacy = "srgb.lutcalc-legacy.v1"
}

public enum SRGBTransfer {
    public static let referenceURL = "https://www.w3.org/TR/2026/CRD-css-color-4-20260913/#predefined-sRGB"

    public static func encode(_ linear: Double, variant: SRGBVariant) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result: Double
        switch variant {
        case .w3cExtended:
            if abs(linear) > 0.0031308 {
                result = (linear < 0 ? -1 : 1) * (1.055 * pow(abs(linear), 1 / 2.4) - 0.055)
            } else {
                result = 12.92 * linear
            }
        case .lutcalcLegacy:
            if linear >= 0.0031308 {
                result = 1.055 * pow(linear, 1 / 2.4) - 0.055
            } else {
                result = 12.92 * linear
            }
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decode(_ encoded: Double, variant: SRGBVariant) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result: Double
        switch variant {
        case .w3cExtended:
            if abs(encoded) <= 0.04045 {
                result = encoded / 12.92
            } else {
                result = (encoded < 0 ? -1 : 1) * pow((abs(encoded) + 0.055) / 1.055, 2.4)
            }
        case .lutcalcLegacy:
            if encoded >= 0.04015966 {
                result = pow((encoded + 0.055) / 1.055, 2.4)
            } else {
                result = encoded / 12.92
            }
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
