import Foundation

public enum LeicaLLogTransfer {
    public static let referenceURL = "research/colour/2026-09-23/whitepapers/leica-llog-v1.9.pdf"

    private static let linearSlope = 8.0
    private static let linearOffset = 0.09
    private static let logSlope = 0.27
    private static let logInputScale = 1.3
    private static let logInputOffset = 0.0115
    private static let logOffset = 0.6
    private static let encodeCut = 0.006
    private static let decodeCut = 0.138

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene <= encodeCut {
            result = linearSlope * scene + linearOffset
        } else {
            result = logSlope * log10(logInputScale * scene + logInputOffset) + logOffset
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data <= decodeCut {
            result = (data - linearOffset) / linearSlope
        } else {
            result = (pow(10, (data - logOffset) / logSlope) - logInputOffset) / logInputScale
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
