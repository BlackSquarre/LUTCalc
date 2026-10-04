import Foundation

/// Normalized CIE L* transfer from ITU-R BT.2380-0 §3.3 / ISO 11664-4.
/// The LUTCalc data wrapper and legacy-grey scale remain explicit at the edge.
public enum CIELStarTransfer {
    public static let referenceURL = "research/colour/2026-09-23/text/whitepapers/itu-bt2380.txt §3.3; ISO 11664-4"
    public static let linearCut = 216.0 / 24389.0
    public static let encodedCut = 216.0 / 2700.0

    private static let core = try! ParameterizedGammaTransfer(
        exponent: 3,
        linearSlope: 24389.0 / 2700.0,
        offset: 0.16,
        linearCut: linearCut,
        encodedCut: encodedCut
    )

    public static func encodeLegacyToLegal(_ value: Double) throws -> Double {
        try core.encodeLegacyToLegal(value)
    }

    public static func decodeLegalToLegacy(_ value: Double) throws -> Double {
        try core.decodeLegalToLegacy(value)
    }

    public static func encodeLegacyToData(_ value: Double) throws -> Double {
        let legal = try encodeLegacyToLegal(value)
        let result = legal * 0.85630498533724 + 0.06256109481916
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        return try decodeLegalToLegacy((value - 0.06256109481916) / 0.85630498533724)
    }
}
