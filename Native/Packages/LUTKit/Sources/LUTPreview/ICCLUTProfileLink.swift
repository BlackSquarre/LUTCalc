import Foundation
import LUTCore

public enum ICCLUTProfileLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case missingTransformTag(String)
    case unsupportedTagType(String)
    case unsupportedEncoding
    case unsupportedRenderingIntent(ICCMatrixTRCRenderingIntent)
}

/// 有界的 ICC LUT profile linking 子集。
///
/// 两个用户提供的 RGB/PCS XYZ profile 通过 D50 PCS XYZ 连接。每个请求的
/// rendering intent 只选择其对应的 ICC A2B/B2A 标签：perceptual 使用
/// `A2B0`/`B2A0`，relative 使用 `A2B1`/`B2A1`，saturation 使用
/// `A2B2`/`B2A2`。relative 仍保留对明确不支持元素的 `A2B0`/`B2A0`
/// fallback；其他 intent 不猜测语义，也不保留用户 profile 的原始 LUT 字节。
public struct ICCLUTProfileLink: Sendable {
    private enum SourceTransform: Sendable {
        case mft(ICCMFTXYZTransform)
        case mab(ICCMABXYZTransform)

        func toPCS(_ rgb: RGB64) throws -> XYZ64 {
            switch self {
            case .mft(let transform): return try transform.rgbToXYZ(rgb)
            case .mab(let transform): return try transform.rgbToXYZ(rgb)
            }
        }
    }

    private enum TargetTransform: Sendable {
        case mft(ICCMFTXYZTransform)
        case mab(ICCMABXYZTransform)

        func fromPCS(_ xyz: XYZ64) throws -> RGB64 {
            switch self {
            case .mft(let transform): return try transform.xyzToRGB(xyz)
            case .mab(let transform): return try transform.xyzToRGB(xyz)
            }
        }
    }

    public let intent: ICCMatrixTRCRenderingIntent
    private let source: SourceTransform
    private let target: TargetTransform
    private let absoluteScale: XYZ64

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        guard intent == .perceptual || intent == .relativeColorimetric || intent == .saturation || intent == .absoluteColorimetric else {
            throw ICCLUTProfileLinkError.unsupportedRenderingIntent(intent)
        }
        let sourceValidation = try Self.validate(sourceProfile)
        let targetValidation = try Self.validate(targetProfile)
        source = try Self.makeSource(profileData: sourceProfile, intent: intent)
        target = try Self.makeTarget(profileData: targetProfile, intent: intent)
        if intent == .absoluteColorimetric {
            let sourceWhite = try Self.mediaWhitePoint(sourceValidation)
            let targetWhite = try Self.mediaWhitePoint(targetValidation)
            absoluteScale = try XYZ64(sourceWhite.x / targetWhite.x,
                                      sourceWhite.y / targetWhite.y,
                                      sourceWhite.z / targetWhite.z)
        } else {
            absoluteScale = try XYZ64(1, 1, 1)
        }
        self.intent = intent
    }

    public func convert(_ encodedRGB: RGB64) throws -> RGB64 {
        let sourcePCS = try source.toPCS(encodedRGB)
        let targetPCS = try XYZ64(sourcePCS.x * absoluteScale.x,
                                  sourcePCS.y * absoluteScale.y,
                                  sourcePCS.z * absoluteScale.z)
        return try target.fromPCS(targetPCS)
    }

    private static func makeSource(profileData: Data,
                                   intent: ICCMatrixTRCRenderingIntent) throws -> SourceTransform {
        let validation = try validate(profileData)
        guard validation.colorSpaceSignature == "RGB " else {
            throw ICCLUTProfileLinkError.unsupportedColorSpace
        }
        guard validation.pcsSignature == "XYZ " else {
            throw ICCLUTProfileLinkError.unsupportedPCS
        }
        let candidates = ICCLUTIntentTransformTags.sourceCandidates(in: validation, intent: intent)
        guard !candidates.isEmpty else {
            throw ICCLUTProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.sourceName(intent))
        }
        var lastUnsupported: ICCLUTProfileLinkError?
        for tag in candidates {
            do {
                return try makeTransform(profileData: profileData, tag: tag, expectedMABType: "mAB ")
            } catch let error as ICCLUTProfileLinkError {
                switch error {
                case .unsupportedTagType, .unsupportedEncoding: break
                default: throw error
                }
                lastUnsupported = error
                continue
            }
        }
        throw lastUnsupported ?? ICCLUTProfileLinkError.unsupportedTagType(ICCLUTIntentTransformTags.sourceName(intent))
    }

    private static func makeTarget(profileData: Data,
                                   intent: ICCMatrixTRCRenderingIntent) throws -> TargetTransform {
        let validation = try validate(profileData)
        guard validation.colorSpaceSignature == "RGB " else {
            throw ICCLUTProfileLinkError.unsupportedColorSpace
        }
        guard validation.pcsSignature == "XYZ " else {
            throw ICCLUTProfileLinkError.unsupportedPCS
        }
        let candidates = ICCLUTIntentTransformTags.targetCandidates(in: validation, intent: intent)
        guard !candidates.isEmpty else {
            throw ICCLUTProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.targetName(intent))
        }
        var lastUnsupported: ICCLUTProfileLinkError?
        for tag in candidates {
            do {
                return try makeTargetTransform(profileData: profileData, tag: tag)
            } catch let error as ICCLUTProfileLinkError {
                switch error {
                case .unsupportedTagType, .unsupportedEncoding: break
                default: throw error
                }
                lastUnsupported = error
                continue
            }
        }
        throw lastUnsupported ?? ICCLUTProfileLinkError.unsupportedTagType(ICCLUTIntentTransformTags.targetName(intent))
    }

    private static func makeTargetTransform(profileData: Data, tag: String) throws -> TargetTransform {
        let payload = try payload(profileData, tag: tag)
        let type = String(decoding: payload.prefix(4), as: UTF8.self)
        switch type {
        case "mft2":
            do { return .mft(try ICCMFTXYZTransform(profileData: profileData, tag: tag)) }
            catch let error as ICCMFTXYZError { throw map(error) }
        case "mAB ", "mBA ":
            guard type == "mBA " else { throw ICCLUTProfileLinkError.unsupportedTagType("direction") }
            do { return .mab(try ICCMABXYZTransform(profileData: profileData, tag: tag)) }
            catch let error as ICCMABXYZError { throw map(error) }
        default:
            throw ICCLUTProfileLinkError.unsupportedTagType(type)
        }
    }

    private static func makeTransform(profileData: Data, tag: String,
                                      expectedMABType: String) throws -> SourceTransform {
        let payload = try payload(profileData, tag: tag)
        let type = String(decoding: payload.prefix(4), as: UTF8.self)
        switch type {
        case "mft2":
            do { return .mft(try ICCMFTXYZTransform(profileData: profileData, tag: tag)) }
            catch let error as ICCMFTXYZError { throw map(error) }
        case "mAB ", "mBA ":
            guard type == expectedMABType else { throw ICCLUTProfileLinkError.unsupportedTagType("direction") }
            do { return .mab(try ICCMABXYZTransform(profileData: profileData, tag: tag)) }
            catch let error as ICCMABXYZError { throw map(error) }
        default:
            throw ICCLUTProfileLinkError.unsupportedTagType(type)
        }
    }

    private static func validate(_ data: Data) throws -> ICCProfileValidation {
        do { return try ICCProfileValidator.validate(data) }
        catch { throw ICCLUTProfileLinkError.invalidProfile }
    }

    private static func payload(_ data: Data, tag: String) throws -> Data {
        do { return try ICCProfileValidator.payload(forTag: tag, in: data) }
        catch { throw ICCLUTProfileLinkError.invalidProfile }
    }

    private static func mediaWhitePoint(_ profile: ICCProfileValidation) throws -> XYZ64 {
        guard let tag = profile.tags.first(where: { $0.signature == "wtpt" }),
              tag.typeSignature == "XYZ ", let values = tag.fixedPointValues,
              values.count == 3, values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw ICCLUTProfileLinkError.invalidProfile
        }
        return try XYZ64(values[0], values[1], values[2])
    }

    private static func map(_ error: ICCMFTXYZError) -> ICCLUTProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedEncoding: return .unsupportedEncoding
        case .unsupportedDirection: return .unsupportedTagType("direction")
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }

    private static func map(_ error: ICCMABXYZError) -> ICCLUTProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedEncoding: return .unsupportedEncoding
        case .unsupportedDirection: return .unsupportedTagType("direction")
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }
}
