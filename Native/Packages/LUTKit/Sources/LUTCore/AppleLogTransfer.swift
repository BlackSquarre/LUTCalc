import Foundation

public enum AppleLogTransfer {
    public static let referenceURL = "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/main/apple/CSC.Apple.AppleLog_to_ACES.ctl"
    public static let log2ReferenceURL = "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/main/apple/CSC.Apple.AppleLog2_to_ACES.ctl"

    private static let r0 = -0.05641088
    private static let rt = 0.01
    private static let c = 47.28711236
    private static let b = 0.00964052
    private static let g = 0.08550479
    private static let d = 0.69336945
    private static let pt = c * (rt - r0) * (rt - r0)

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene >= rt {
            result = g * log2(scene + b) + d
        } else if scene >= r0 {
            result = c * (scene - r0) * (scene - r0)
        } else {
            result = 0
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data >= pt {
            result = pow(2, (data - d) / g) - b
        } else if data >= 0 {
            result = sqrt(data / c) + r0
        } else {
            result = r0
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
