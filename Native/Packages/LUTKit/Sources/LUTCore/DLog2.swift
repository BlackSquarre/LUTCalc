import Foundation

public enum DLog2 {
    public static let algorithmID = "dji.dlog2.v1"
    public static let referenceID = "IDT.DJI.DLog2_DGamut2.a1.v1"

    private static let a = 16.285770761945304
    private static let h = 475.0 / (pow(2.0, a) - 1.0)
    private static let k1 = 0.059439938321493
    private static let b1 = 0.304985337243402
    private static let k2 = 2.960935245492250
    private static let b2 = 0.148314799066323
    private static let cut = 0.028961695254132

    public static func decodeDataToScene(_ signal: Double) throws -> Double {
        guard signal.isFinite else { throw NumericError.nonFinite }
        let output: Double
        if signal >= b1 {
            output = h * (pow(2.0, a * signal) - 1.0)
        } else if signal >= b2 {
            output = pow(2.0, (signal - b1) / k1 + log2(0.18))
        } else {
            output = (signal - b2) / k2 + cut
        }
        guard output.isFinite else { throw NumericError.nonFinite }
        return output
    }

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let output: Double
        if scene >= 0.18 {
            output = log2(scene / h + 1.0) / a
        } else if scene >= cut {
            output = k1 * log2(scene / 0.18) + b1
        } else {
            output = k2 * (scene - cut) + b2
        }
        guard output.isFinite else { throw NumericError.nonFinite }
        return output
    }

    public static func decodeDataToLegacy(_ signal: Double) throws -> Double {
        try LinearScale.sceneToLegacy(decodeDataToScene(signal))
    }

    public static func encodeLegacyToData(_ legacy: Double) throws -> Double {
        try encodeSceneToData(LinearScale.legacyToScene(legacy))
    }

    public static func decodeVideoToScene(_ video: Double, codeRange: CodeRange) throws -> Double {
        try decodeDataToScene(codeRange.videoToData(video))
    }

    public static func encodeSceneToVideo(_ scene: Double, codeRange: CodeRange) throws -> Double {
        try codeRange.dataToVideo(encodeSceneToData(scene))
    }
}
