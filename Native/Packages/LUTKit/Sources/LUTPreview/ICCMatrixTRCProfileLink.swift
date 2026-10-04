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
/// Only relative colorimetric intent is supported; this path does not perform
/// gamut mapping or emulate LUT-based perceptual, saturation, or absolute intent.
public struct ICCMatrixTRCProfileLink: Sendable {
    public let intent: ICCMatrixTRCRenderingIntent
    private let source: ICCMatrixTRCTransform
    private let target: ICCMatrixTRCTransform

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        guard intent == .relativeColorimetric else {
            throw ICCMatrixTRCProfileLinkError.unsupportedRenderingIntent(intent)
        }
        source = try ICCMatrixTRCTransform(profileData: sourceProfile)
        target = try ICCMatrixTRCTransform(profileData: targetProfile)
        let sourceWhite = source.profileWhitePoint
        let targetWhite = target.profileWhitePoint
        let tolerance = 2e-12 * max(1.0, abs(sourceWhite.x), abs(sourceWhite.y), abs(sourceWhite.z),
                                     abs(targetWhite.x), abs(targetWhite.y), abs(targetWhite.z))
        guard abs(sourceWhite.x - targetWhite.x) <= tolerance,
              abs(sourceWhite.y - targetWhite.y) <= tolerance,
              abs(sourceWhite.z - targetWhite.z) <= tolerance else {
            throw ICCMatrixTRCProfileLinkError.mismatchedPCSWhitePoint
        }
        self.intent = intent
    }

    public func convert(_ encodedRGB: RGB64) throws -> RGB64 {
        let pcsXYZ = try source.encodedRGBToXYZ(encodedRGB)
        return try target.xyzToEncodedRGB(pcsXYZ)
    }
}
