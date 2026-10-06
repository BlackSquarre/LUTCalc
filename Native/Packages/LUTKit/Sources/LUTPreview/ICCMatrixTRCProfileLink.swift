import Foundation
import LUTCore

public enum ICCMatrixTRCRenderingIntent: Int, Codable, Sendable {
    case perceptual = 0
    case relativeColorimetric = 1
    case saturation = 2
    case absoluteColorimetric = 3
}

public enum ICCMatrixTRCProfileLinkError: Error, Equatable, Sendable {
    case unsupportedRenderingIntent(ICCMatrixTRCRenderingIntent)
    case mismatchedPCSWhitePoint
}

/// A bounded RGB matrix/TRC profile connection through ICC PCS XYZ.
/// Relative colorimetric remains limited to matching media white points. For
/// ICC-absolute colorimetric, the media-relative PCS values are scaled by the
/// source-to-target media white point ratio from ICC.1:2022-05 §6.3.2.2.
/// This path does not perform gamut mapping, black point compensation, or
/// LUT-based intent rendering.
public struct ICCMatrixTRCProfileLink: Sendable {
    public let intent: ICCMatrixTRCRenderingIntent
    private let source: ICCMatrixTRCTransform
    private let target: ICCMatrixTRCTransform
    private let absoluteScale: XYZ64

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        guard intent == .relativeColorimetric || intent == .absoluteColorimetric else {
            throw ICCMatrixTRCProfileLinkError.unsupportedRenderingIntent(intent)
        }
        source = try ICCMatrixTRCTransform(profileData: sourceProfile)
        target = try ICCMatrixTRCTransform(profileData: targetProfile)
        let sourceWhite = source.profileWhitePoint
        let targetWhite = target.profileWhitePoint
        let tolerance = 2e-12 * max(1.0, abs(sourceWhite.x), abs(sourceWhite.y), abs(sourceWhite.z),
                                     abs(targetWhite.x), abs(targetWhite.y), abs(targetWhite.z))
        if intent == .relativeColorimetric {
            guard abs(sourceWhite.x - targetWhite.x) <= tolerance,
                  abs(sourceWhite.y - targetWhite.y) <= tolerance,
                  abs(sourceWhite.z - targetWhite.z) <= tolerance else {
                throw ICCMatrixTRCProfileLinkError.mismatchedPCSWhitePoint
            }
        }
        // Equations (4)-(6) followed by (1)-(3): source relative -> absolute
        // -> target relative. The PCS white cancels, leaving this ratio.
        absoluteScale = try intent == .absoluteColorimetric
            ? XYZ64(sourceWhite.x / targetWhite.x,
                    sourceWhite.y / targetWhite.y,
                    sourceWhite.z / targetWhite.z)
            : XYZ64(1, 1, 1)
        self.intent = intent
    }

    public func convert(_ encodedRGB: RGB64) throws -> RGB64 {
        let sourcePCS = try source.encodedRGBToXYZ(encodedRGB)
        let targetPCS = try XYZ64(
            sourcePCS.x * absoluteScale.x,
            sourcePCS.y * absoluteScale.y,
            sourcePCS.z * absoluteScale.z
        )
        return try target.xyzToEncodedRGB(targetPCS)
    }
}
