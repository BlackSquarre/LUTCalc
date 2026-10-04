import Foundation
import LUTCore

/// 统一的 RGB/PCS XYZ profile linking 入口。
///
/// 这里只做已验证 profile 形式的明确分派：两个 matrix/TRC profile 走
/// `ICCMatrixTRCProfileLink`，两个带 relative-intent LUT 标签的 profile 走
/// `ICCLUTProfileLink`。混合形式、缺少对应方向或未知 profile 类型均拒绝，
/// 不根据标签内容猜测颜色管理语义。
public enum ICCRGBProfileLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedProfileKind
    case mismatchedProfileKinds
    case mismatchedPCS
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedRenderingIntent(ICCMatrixTRCRenderingIntent)
    case matrix(ICCMatrixTRCProfileLinkError)
    case lut(ICCLUTProfileLinkError)
    case lab(ICCLabProfileLinkError)
}

public enum ICCLabProfileLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case missingTransformTag(String)
    case unsupportedTagType(String)
    case unsupportedEncoding
    case unsupportedDirection
}

public struct ICCRGBProfileLink: Sendable {
    private enum Route: Sendable {
        case matrix(ICCMatrixTRCProfileLink)
        case lut(ICCLUTProfileLink)
        case lab(source: ICCLabSourceTransform, target: ICCLabTargetTransform)
    }

    private enum ICCLabSourceTransform: Sendable {
        case mft(ICCMFTLabTransform)
        case mab(ICCMABLabTransform)

        func convert(_ rgb: RGB64) throws -> CIELABColor {
            switch self {
            case .mft(let transform): return try transform.rgbToLab(rgb)
            case .mab(let transform): return try transform.rgbToLab(rgb)
            }
        }
    }

    private enum ICCLabTargetTransform: Sendable {
        case mft(ICCMFTLabTransform)
        case mab(ICCMABLabTransform)

        func convert(_ lab: CIELABColor) throws -> RGB64 {
            switch self {
            case .mft(let transform): return try transform.labToRGB(lab)
            case .mab(let transform): return try transform.labToRGB(lab)
            }
        }
    }

    public let intent: ICCMatrixTRCRenderingIntent
    private let route: Route

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        guard intent == .relativeColorimetric else {
            throw ICCRGBProfileLinkError.unsupportedRenderingIntent(intent)
        }

        let source = try Self.validate(sourceProfile)
        let target = try Self.validate(targetProfile)
        guard source.colorSpaceSignature == "RGB ", target.colorSpaceSignature == "RGB " else {
            throw ICCRGBProfileLinkError.unsupportedColorSpace
        }
        guard source.pcsSignature == target.pcsSignature else {
            throw ICCRGBProfileLinkError.mismatchedPCS
        }

        if source.pcsSignature == "Lab " {
            guard ICCRelativeIntentTransformTags.source(in: source) != nil,
                  ICCRelativeIntentTransformTags.target(in: target) != nil else {
                throw ICCRGBProfileLinkError.unsupportedProfileKind
            }
            do {
                route = .lab(source: try Self.makeLabSource(profileData: sourceProfile,
                                                            profile: source),
                             target: try Self.makeLabTarget(profileData: targetProfile,
                                                            profile: target))
            } catch let error as ICCLabProfileLinkError {
                throw ICCRGBProfileLinkError.lab(error)
            }
            self.intent = intent
            return
        }

        guard source.pcsSignature == "XYZ ", target.pcsSignature == "XYZ " else {
            throw ICCRGBProfileLinkError.unsupportedPCS
        }

        let sourceHasLUT = ICCRelativeIntentTransformTags.source(in: source) != nil
        let targetHasLUT = ICCRelativeIntentTransformTags.target(in: target) != nil
        guard sourceHasLUT == targetHasLUT else {
            throw ICCRGBProfileLinkError.mismatchedProfileKinds
        }

        do {
            if sourceHasLUT {
                route = .lut(try ICCLUTProfileLink(sourceProfile: sourceProfile,
                                                   targetProfile: targetProfile,
                                                   intent: intent))
            } else {
                route = .matrix(try ICCMatrixTRCProfileLink(sourceProfile: sourceProfile,
                                                            targetProfile: targetProfile,
                                                            intent: intent))
            }
        } catch let error as ICCLUTProfileLinkError {
            throw ICCRGBProfileLinkError.lut(error)
        } catch let error as ICCMatrixTRCProfileLinkError {
            throw ICCRGBProfileLinkError.matrix(error)
        }
        self.intent = intent
    }

    public func convert(_ encodedRGB: RGB64) throws -> RGB64 {
        switch route {
        case .matrix(let link): return try link.convert(encodedRGB)
        case .lut(let link): return try link.convert(encodedRGB)
        case .lab(let source, let target):
            return try target.convert(source.convert(encodedRGB))
        }
    }

    /// Explicitly links a pixel buffer through the validated profile pair.
    ///
    /// This method is intentionally separate from `CPUPreview` and
    /// `PreviewImageDecoder`: decoding an image or rendering the default
    /// preview never calls it implicitly. The caller must provide the alpha
    /// representation and request profile linking itself.
    public func convert(_ pixels: [RGBA64], inputAlpha: AlphaMode,
                        outputAlpha: AlphaMode) throws -> [RGBA64] {
        var output: [RGBA64] = []
        output.reserveCapacity(pixels.count)
        for pixel in pixels {
            let straight: RGB64
            if pixel.alpha == 0 {
                straight = try RGB64(0, 0, 0)
            } else if inputAlpha == .premultiplied {
                straight = try RGB64(pixel.rgb.r / pixel.alpha,
                                     pixel.rgb.g / pixel.alpha,
                                     pixel.rgb.b / pixel.alpha)
            } else {
                straight = pixel.rgb
            }

            // Transparent pixels carry no color information. Keep them black
            // and avoid turning hidden RGB into visible values at a later
            // unpremultiplication boundary.
            let linked = pixel.alpha == 0 ? straight : try convert(straight)
            let encoded: RGB64
            if outputAlpha == .premultiplied {
                encoded = try RGB64(linked.r * pixel.alpha,
                                    linked.g * pixel.alpha,
                                    linked.b * pixel.alpha)
            } else {
                encoded = linked
            }
            output.append(try RGBA64(rgb: encoded, alpha: pixel.alpha))
        }
        return output
    }

    private static func validate(_ data: Data) throws -> ICCProfileValidation {
        do { return try ICCProfileValidator.validate(data) }
        catch { throw ICCRGBProfileLinkError.invalidProfile }
    }

    private static func makeLabSource(profileData: Data,
                                      profile: ICCProfileValidation) throws -> ICCLabSourceTransform {
        var lastUnsupported: ICCLabProfileLinkError?
        for tag in ICCRelativeIntentTransformTags.sourceCandidates(in: profile) {
            do {
                let payload = try labPayload(profileData, tag: tag)
                let type = String(decoding: payload.prefix(4), as: UTF8.self)
                switch type {
                case "mft1", "mft2": return .mft(try ICCMFTLabTransform(profileData: profileData, tag: tag))
                case "mAB ": return .mab(try ICCMABLabTransform(profileData: profileData, tag: tag))
                case "mBA ": throw ICCLabProfileLinkError.unsupportedDirection
                default: throw ICCLabProfileLinkError.unsupportedTagType(type)
                }
            } catch let error as ICCLabProfileLinkError {
                switch error {
                case .unsupportedTagType, .unsupportedDirection:
                    lastUnsupported = error
                    continue
                default:
                    throw error
                }
            } catch let error as ICCMFTLabError { throw map(error) }
              catch let error as ICCMABLabError { throw map(error) }
        }
        throw lastUnsupported ?? ICCLabProfileLinkError.unsupportedTagType("A2B1/A2B0")
    }

    private static func makeLabTarget(profileData: Data,
                                      profile: ICCProfileValidation) throws -> ICCLabTargetTransform {
        var lastUnsupported: ICCLabProfileLinkError?
        for tag in ICCRelativeIntentTransformTags.targetCandidates(in: profile) {
            do {
                let payload = try labPayload(profileData, tag: tag)
                let type = String(decoding: payload.prefix(4), as: UTF8.self)
                switch type {
                case "mft1", "mft2": return .mft(try ICCMFTLabTransform(profileData: profileData, tag: tag))
                case "mBA ": return .mab(try ICCMABLabTransform(profileData: profileData, tag: tag))
                case "mAB ": throw ICCLabProfileLinkError.unsupportedDirection
                default: throw ICCLabProfileLinkError.unsupportedTagType(type)
                }
            } catch let error as ICCLabProfileLinkError {
                switch error {
                case .unsupportedTagType, .unsupportedDirection:
                    lastUnsupported = error
                    continue
                default:
                    throw error
                }
            } catch let error as ICCMFTLabError { throw map(error) }
              catch let error as ICCMABLabError { throw map(error) }
        }
        throw lastUnsupported ?? ICCLabProfileLinkError.unsupportedTagType("B2A1/B2A0")
    }

    private static func labPayload(_ data: Data, tag: String) throws -> Data {
        do { return try ICCProfileValidator.payload(forTag: tag, in: data) }
        catch { throw ICCLabProfileLinkError.invalidProfile }
    }

    private static func map(_ error: ICCMFTLabError) -> ICCLabProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .transform: return .invalidProfile
        case .outsideDomain, .nonFinite: return .invalidProfile
        }
    }

    private static func map(_ error: ICCMABLabError) -> ICCLabProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .transform: return .invalidProfile
        case .outsideDomain, .nonFinite: return .invalidProfile
        }
    }
}
