import Foundation

public enum ILogTransfer {
    public static let referenceURL = "https://wassets.insta360.com/common/31f0330509384b7b8ba0a07f4ff4eb13/Insta360_10-bit_I-Log_White_Paper.pdf"

    private static let slope = 5.77837328
    private static let offset = 0.09055934
    private static let logOffset = 0.623992
    private static let logSlope = 0.280055
    private static let logInputOffset = 0.01
    private static let encodeCut = 0.01104854
    private static let decodeCut = 0.154402

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene > encodeCut {
            result = logOffset + logSlope * log10(scene + logInputOffset)
        } else {
            result = slope * scene + offset
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < decodeCut {
            result = (data - offset) / slope
        } else {
            result = pow(10, (data - logOffset) / logSlope) - logInputOffset
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
