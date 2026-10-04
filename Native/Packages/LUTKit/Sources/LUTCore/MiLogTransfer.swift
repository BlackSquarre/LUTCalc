import Foundation

public enum MiLogTransfer {
    public static let referenceURL = "https://cdn.alsgp0.fds.api.mi-img.com/e-commerce/global/Mi-Log_ACES%20Profiles.zip"

    private static let r0 = -0.09023729
    private static let rt = 0.01974185
    private static let c = 18.10531998
    private static let gamma = 0.09271529
    private static let beta = 0.01384578
    private static let delta = 0.67291850
    private static let pt = c * (rt - r0) * (rt - r0)

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene < r0 {
            result = 0
        } else if scene < rt {
            result = c * (scene - r0) * (scene - r0)
        } else {
            result = gamma * log2(scene + beta) + delta
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < 0 {
            result = r0
        } else if data < pt {
            result = sqrt(data / c) + r0
        } else {
            result = exp2((data - delta) / gamma) - beta
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
