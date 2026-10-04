import Foundation

public enum VLogTransfer {
    public static let referenceURL = "https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf"

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene < 0.01 {
            result = 5.6 * scene + 0.125
        } else {
            result = 0.241514 * log10(scene + 0.00873) + 0.598206
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < 0.181 {
            result = (data - 0.125) / 5.6
        } else {
            result = pow(10, (data - 0.598206) / 0.241514) - 0.00873
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
