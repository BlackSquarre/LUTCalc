import Foundation

/// GoPro GP-Log2 base-600 scalar transfer, restricted to the documented
/// normalized [0, 1] subset. Negative log extension is intentionally omitted.
public enum GPLog2Transfer {
    public static let referenceURL = "research/colour/2026-09-23/reference-code/gopro-gplog2.html:LOGBASE/invLog/logEnc"
    private static let base = 600.0

    public static func encodeSceneToData(_ value: Double) throws -> Double {
        guard value.isFinite, (0...1).contains(value) else { throw NumericError.invalidDomain }
        let result = log((base - 1) * value + 1) / log(base)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ value: Double) throws -> Double {
        guard value.isFinite, (0...1).contains(value) else { throw NumericError.invalidDomain }
        let result = (pow(base, value) - 1) / (base - 1)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
