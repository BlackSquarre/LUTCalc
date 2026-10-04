import Foundation

public enum KineLog3Transfer {
    public static let referenceURL = "research/colour/2026-09-23/pages/kine-spec.html"

    private static let a = 66.64
    private static let b = 0.296
    private static let c = 0.907136
    private static let d = 0.092864
    private static let cut = -0.008239
    private static let slope = 0.017178

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene < cut {
            result = (scene - cut) / slope
        } else {
            result = log10(a * scene + 1) * b * c + d
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < 0 {
            result = data * slope + cut
        } else {
            result = (pow(10, (data - d) / (b * c)) - 1) / a
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
