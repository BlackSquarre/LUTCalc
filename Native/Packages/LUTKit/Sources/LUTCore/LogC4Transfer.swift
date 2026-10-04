import Foundation

public enum LogC4Transfer {
    public static let referenceURL = "https://www.arri.com/resource/blob/278790/f3318e8c9c65617d8c5ca3f8b3e32051/2023-05-arri-logc4-specification-data.pdf"

    private static let a = (pow(2.0, 18.0) - 16.0) / 117.45
    private static let b = (1023.0 - 95.0) / 1023.0
    private static let c = 95.0 / 1023.0
    private static let s = 7.0 * log(2.0) * pow(2.0, 7.0 - 14.0 * c / b) / (a * b)
    private static let t = (pow(2.0, -14.0 * c / b + 6.0) - 64.0) / a

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene < t {
            result = (scene - t) / s
        } else {
            result = (log2(a * scene + 64.0) - 6.0) / 14.0 * b + c
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < 0 {
            result = data * s + t
        } else {
            result = (pow(2.0, 14.0 * (data - c) / b + 6.0) - 64.0) / a
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
