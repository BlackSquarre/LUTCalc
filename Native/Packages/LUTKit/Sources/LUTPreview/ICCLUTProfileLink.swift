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
/// 两个用户提供的 RGB/PCS XYZ profile 通过 D50 PCS XYZ 连接：relative
/// colorimetric 优先使用 `A2B1`/`B2A1`，缺少或处理元素不受支持时按 ICC
/// precedence 尝试 `A2B0`/`B2A0`。损坏标签不触发 fallback。当前只接受 16 位 `mft2` 与
/// 16 位 CLUT 的 `mAB`/`mBA`，不猜测 perceptual、saturation 或 gamut
/// mapping 语义，也不保留用户 profile 的原始 LUT 字节。
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

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        guard intent == .relativeColorimetric else {
            throw ICCLUTProfileLinkError.unsupportedRenderingIntent(intent)
        }
        source = try Self.makeSource(profileData: sourceProfile)
        target = try Self.makeTarget(profileData: targetProfile)
        self.intent = intent
    }

    public func convert(_ encodedRGB: RGB64) throws -> RGB64 {
        try target.fromPCS(source.toPCS(encodedRGB))
    }

    private static func makeSource(profileData: Data) throws -> SourceTransform {
        let validation = try validate(profileData)
        guard validation.colorSpaceSignature == "RGB " else {
            throw ICCLUTProfileLinkError.unsupportedColorSpace
        }
        guard validation.pcsSignature == "XYZ " else {
            throw ICCLUTProfileLinkError.unsupportedPCS
        }
        let candidates = ICCRelativeIntentTransformTags.sourceCandidates(in: validation)
        guard !candidates.isEmpty else {
            throw ICCLUTProfileLinkError.missingTransformTag("A2B1/A2B0")
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
        throw lastUnsupported ?? ICCLUTProfileLinkError.unsupportedTagType("A2B1/A2B0")
    }

    private static func makeTarget(profileData: Data) throws -> TargetTransform {
        let validation = try validate(profileData)
        guard validation.colorSpaceSignature == "RGB " else {
            throw ICCLUTProfileLinkError.unsupportedColorSpace
        }
        guard validation.pcsSignature == "XYZ " else {
            throw ICCLUTProfileLinkError.unsupportedPCS
        }
        let candidates = ICCRelativeIntentTransformTags.targetCandidates(in: validation)
        guard !candidates.isEmpty else {
            throw ICCLUTProfileLinkError.missingTransformTag("B2A1/B2A0")
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
        throw lastUnsupported ?? ICCLUTProfileLinkError.unsupportedTagType("B2A1/B2A0")
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
