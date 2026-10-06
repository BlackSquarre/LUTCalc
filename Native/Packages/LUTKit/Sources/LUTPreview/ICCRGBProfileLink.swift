import Foundation
import LUTCore

/// 统一的 RGB/PCS XYZ profile linking 入口。
///
/// 这里只做已验证 profile 形式的明确分派：两个 matrix/TRC profile 走
/// `ICCMatrixTRCProfileLink`，两个带 relative-intent LUT 标签的 profile 走
/// `ICCLUTProfileLink`。matrix/TRC 路径还支持白点相同的 absolute colorimetric
/// 子集；`D2B0`...`D2B3`/`B2D0`...`B2D3` 的三通道 `mpet` 子集使用
/// float32 PCS，不读取媒体白点；传统 XYZ LUT absolute 与未支持的
/// profile 形式仍明确拒绝，传统 Lab relative/absolute 子集另按 PCS 白点路由。
/// 混合形式、缺少对应方向或未知 profile 类型均拒绝，不根据标签内容猜测
/// 颜色管理语义。
public enum ICCRGBProfileLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedProfileKind
    case mismatchedProfileKinds
    case mismatchedPCS
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedRenderingIntent(ICCMatrixTRCRenderingIntent)
    /// Generic device arrays are only defined for the validated MPE route.
    case unsupportedDeviceArrayRoute
    /// The RGB convenience API cannot represent a non-three-channel device.
    case rgbRouteRequiresThreeChannels(source: Int, target: Int)
    case incompletePerceptualMPEPair
    case incompleteRelativeMPEPair
    case incompleteSaturationMPEPair
    case incompleteAbsoluteMPEPair
    case matrix(ICCMatrixTRCProfileLinkError)
    case lut(ICCLUTProfileLinkError)
    case mpet(ICCMPEError)
    case traditional(ICCTraditionalProfileLinkError)
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
    case missingMediaWhitePoint
    case malformedMediaWhitePoint
}

public enum ICCTraditionalProfileLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case missingTransformTag(String)
    case unsupportedTagType(String)
    case unsupportedEncoding
    case unsupportedDirection
    case unsupportedRenderingIntent(ICCMatrixTRCRenderingIntent)
}

public struct ICCRGBProfileLink: Sendable {
    private enum Route: Sendable {
        case matrix(ICCMatrixTRCProfileLink)
        case lut(ICCLUTProfileLink)
        case mpet(source: ICCMPETransform, target: ICCMPETransform)
        case mpetLab(source: ICCMPETransform, target: ICCMPETransform)
        case traditionalXYZ(source: ICCTraditionalXYZSource,
                            target: ICCTraditionalXYZTarget)
        case traditionalXYZAbsolute(source: ICCTraditionalXYZSource,
                                    target: ICCTraditionalXYZTarget,
                                    scale: XYZ64)
        case traditionalLab(source: ICCTraditionalLabSource,
                            target: ICCTraditionalLabTarget)
        case traditionalLabAbsolute(source: ICCTraditionalLabSource,
                                    target: ICCTraditionalLabTarget,
                                    scale: XYZ64)
        case lab(source: ICCLabSourceTransform, target: ICCLabTargetTransform)
        case labAbsolute(source: ICCLabSourceTransform, target: ICCLabTargetTransform,
                         scale: XYZ64)
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

        func toRelativePCSXYZ(_ rgb: RGB64) throws -> XYZ64 {
            switch self {
            case .mft(let transform): return try transform.rgbToRelativePCSXYZ(rgb)
            case .mab(let transform): return try transform.rgbToRelativePCSXYZ(rgb)
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

        func fromRelativePCSXYZ(_ xyz: XYZ64) throws -> RGB64 {
            switch self {
            case .mft(let transform): return try transform.relativePCSXYZToRGB(xyz)
            case .mab(let transform): return try transform.relativePCSXYZToRGB(xyz)
            }
        }
    }

    private enum ICCTraditionalXYZSource: Sendable {
        case mft(ICCMFTXYZTransform)
        case mab(ICCMABXYZTransform)

        func convert(_ device: [Double]) throws -> XYZ64 {
            switch self {
            case .mft(let transform): return try transform.deviceToXYZ(device)
            case .mab(let transform): return try transform.deviceToXYZ(device)
            }
        }
    }

    private enum ICCTraditionalXYZTarget: Sendable {
        case mft(ICCMFTXYZTransform)
        case mab(ICCMABXYZTransform)

        func convert(_ xyz: XYZ64) throws -> [Double] {
            switch self {
            case .mft(let transform): return try transform.xyzToDevice(xyz)
            case .mab(let transform): return try transform.xyzToDevice(xyz)
            }
        }
    }

    private enum ICCTraditionalLabSource: Sendable {
        case mft(ICCMFTLabTransform)
        case mab(ICCMABLabTransform)

        func convert(_ device: [Double]) throws -> CIELABColor {
            switch self {
            case .mft(let transform): return try transform.deviceToLab(device)
            case .mab(let transform): return try transform.deviceToLab(device)
            }
        }

        func toRelativePCSXYZ(_ device: [Double]) throws -> XYZ64 {
            try convert(device).toXYZ(white: .d50)
        }
    }

    private enum ICCTraditionalLabTarget: Sendable {
        case mft(ICCMFTLabTransform)
        case mab(ICCMABLabTransform)

        func convert(_ lab: CIELABColor) throws -> [Double] {
            switch self {
            case .mft(let transform): return try transform.labToDevice(lab)
            case .mab(let transform): return try transform.labToDevice(lab)
            }
        }

        func fromRelativePCSXYZ(_ xyz: XYZ64) throws -> [Double] {
            try convert(CIELABColorSpace.fromXYZ(xyz, white: .d50))
        }
    }

    public let intent: ICCMatrixTRCRenderingIntent
    /// Source device channel count declared by the selected profile route.
    public let sourceDeviceChannels: Int
    /// Target device channel count declared by the selected profile route.
    public let targetDeviceChannels: Int
    private let route: Route

    public init(sourceProfile: Data, targetProfile: Data,
                intent: ICCMatrixTRCRenderingIntent) throws {
        let source = try Self.validate(sourceProfile)
        let target = try Self.validate(targetProfile)
        // ICC device-to-device linking accepts device profiles only. A
        // device-link profile has its own executor, while abstract,
        // named-colour and colour-space profiles do not describe a device
        // endpoint and must not be guessed into this route. Legacy synthetic
        // fixtures may leave the class field zeroed, so nil remains accepted.
        guard Self.isDeviceProfileClass(source.profileClass),
              Self.isDeviceProfileClass(target.profileClass) else {
            throw ICCRGBProfileLinkError.unsupportedProfileKind
        }
        guard source.pcsSignature == target.pcsSignature else {
            throw ICCRGBProfileLinkError.mismatchedPCS
        }

        let mpePair: (source: String, target: String, incomplete: ICCRGBProfileLinkError) = {
            switch intent {
            case .perceptual: ("D2B0", "B2D0", .incompletePerceptualMPEPair)
            case .relativeColorimetric: ("D2B1", "B2D1", .incompleteRelativeMPEPair)
            case .saturation: ("D2B2", "B2D2", .incompleteSaturationMPEPair)
            case .absoluteColorimetric: ("D2B3", "B2D3", .incompleteAbsoluteMPEPair)
            }
        }()
        let sourceHasMPE = source.tagSignatures.contains(mpePair.source)
        let targetHasMPE = target.tagSignatures.contains(mpePair.target)
        if sourceHasMPE || targetHasMPE {
            guard sourceHasMPE, targetHasMPE else { throw mpePair.incomplete }
            guard source.pcsSignature == "XYZ " || source.pcsSignature == "Lab " else {
                throw ICCRGBProfileLinkError.unsupportedPCS
            }
            do {
                let sourceTransform = try ICCMPETransform(profileData: sourceProfile,
                                                          tag: mpePair.source)
                let targetTransform = try ICCMPETransform(profileData: targetProfile,
                                                          tag: mpePair.target)
                guard sourceTransform.pcs == targetTransform.pcs else {
                    throw ICCMPEError.channelMismatch
                }
                if sourceTransform.pcs == .xyz {
                    route = .mpet(source: sourceTransform, target: targetTransform)
                } else {
                    route = .mpetLab(source: sourceTransform, target: targetTransform)
                }
                self.sourceDeviceChannels = sourceTransform.inputChannels
                self.targetDeviceChannels = targetTransform.outputChannels
            } catch let error as ICCMPEError {
                throw ICCRGBProfileLinkError.mpet(error)
            }
            self.intent = intent
            return
        }

        if source.colorSpaceSignature != "RGB " || target.colorSpaceSignature != "RGB " ||
            source.colorChannelCount != 3 || target.colorChannelCount != 3 {
            // The traditional RGB convenience boundary does not link mixed
            // device color spaces. Dedicated non-RGB routes remain valid
            // when both endpoints declare the same device color space.
            guard source.colorSpaceSignature == target.colorSpaceSignature else {
                throw ICCRGBProfileLinkError.unsupportedColorSpace
            }
            guard intent == .relativeColorimetric || intent == .absoluteColorimetric else {
                throw ICCTraditionalProfileLinkError.unsupportedRenderingIntent(intent)
            }
            do {
                if source.pcsSignature != target.pcsSignature ||
                    (source.pcsSignature != "XYZ " && source.pcsSignature != "Lab ") {
                    throw ICCTraditionalProfileLinkError.unsupportedPCS
                }
                if source.pcsSignature == "XYZ " {
                    let sourceTransform = try Self.makeTraditionalXYZSource(profileData: sourceProfile, profile: source, intent: intent)
                    let targetTransform = try Self.makeTraditionalXYZTarget(profileData: targetProfile, profile: target, intent: intent)
                    if intent == .absoluteColorimetric {
                        let sourceWhite = try Self.mediaWhitePoint(source)
                        let targetWhite = try Self.mediaWhitePoint(target)
                        route = .traditionalXYZAbsolute(source: sourceTransform, target: targetTransform,
                                                        scale: try XYZ64(sourceWhite.x / targetWhite.x,
                                                                         sourceWhite.y / targetWhite.y,
                                                                         sourceWhite.z / targetWhite.z))
                    } else {
                        route = .traditionalXYZ(source: sourceTransform, target: targetTransform)
                    }
                } else {
                    let sourceTransform = try Self.makeTraditionalLabSource(profileData: sourceProfile, profile: source, intent: intent)
                    let targetTransform = try Self.makeTraditionalLabTarget(profileData: targetProfile, profile: target, intent: intent)
                    if intent == .absoluteColorimetric {
                        let sourceWhite = try Self.mediaWhitePoint(source)
                        let targetWhite = try Self.mediaWhitePoint(target)
                        route = .traditionalLabAbsolute(source: sourceTransform, target: targetTransform,
                                                        scale: try XYZ64(sourceWhite.x / targetWhite.x,
                                                                         sourceWhite.y / targetWhite.y,
                                                                         sourceWhite.z / targetWhite.z))
                    } else {
                        route = .traditionalLab(source: sourceTransform, target: targetTransform)
                    }
                }
                self.sourceDeviceChannels = source.colorChannelCount ?? 0
                self.targetDeviceChannels = target.colorChannelCount ?? 0
            } catch let error as ICCTraditionalProfileLinkError {
                if error == .unsupportedColorSpace {
                    throw ICCRGBProfileLinkError.unsupportedColorSpace
                }
                throw ICCRGBProfileLinkError.traditional(error)
            }
            self.intent = intent
            return
        }

        // All non-MPE routes remain the established three-channel RGB boundary.
        guard source.colorSpaceSignature == "RGB ", target.colorSpaceSignature == "RGB " else {
            throw ICCRGBProfileLinkError.unsupportedColorSpace
        }
        self.sourceDeviceChannels = 3
        self.targetDeviceChannels = 3

        if source.pcsSignature == "Lab " {
            guard ICCRelativeIntentTransformTags.source(in: source) != nil,
                  ICCRelativeIntentTransformTags.target(in: target) != nil else {
                throw ICCRGBProfileLinkError.unsupportedProfileKind
            }
            do {
                let sourceTransform = try Self.makeLabSource(profileData: sourceProfile,
                                                             profile: source)
                let targetTransform = try Self.makeLabTarget(profileData: targetProfile,
                                                             profile: target)
                if intent == .absoluteColorimetric {
                    let sourceWhite = try Self.mediaWhitePoint(source)
                    let targetWhite = try Self.mediaWhitePoint(target)
                    route = .labAbsolute(
                        source: sourceTransform,
                        target: targetTransform,
                        scale: try XYZ64(sourceWhite.x / targetWhite.x,
                                         sourceWhite.y / targetWhite.y,
                                         sourceWhite.z / targetWhite.z)
                    )
                } else if intent == .relativeColorimetric {
                    route = .lab(source: sourceTransform, target: targetTransform)
                } else {
                    throw ICCRGBProfileLinkError.unsupportedRenderingIntent(intent)
                }
            } catch let error as ICCLabProfileLinkError {
                throw ICCRGBProfileLinkError.lab(error)
            }
            self.intent = intent
            return
        }

        guard source.pcsSignature == "XYZ ", target.pcsSignature == "XYZ " else {
            throw ICCRGBProfileLinkError.unsupportedPCS
        }

        guard intent == .relativeColorimetric || intent == .absoluteColorimetric else {
            throw ICCRGBProfileLinkError.unsupportedRenderingIntent(intent)
        }

        let sourceHasLUT = ICCRelativeIntentTransformTags.source(in: source) != nil
        let targetHasLUT = ICCRelativeIntentTransformTags.target(in: target) != nil
        guard sourceHasLUT == targetHasLUT else {
            throw ICCRGBProfileLinkError.mismatchedProfileKinds
        }
        guard intent == .relativeColorimetric || !sourceHasLUT else {
            throw ICCRGBProfileLinkError.unsupportedRenderingIntent(intent)
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
        case .mpet:
            guard sourceDeviceChannels == 3, targetDeviceChannels == 3 else {
                throw ICCRGBProfileLinkError.rgbRouteRequiresThreeChannels(
                    source: sourceDeviceChannels, target: targetDeviceChannels)
            }
            let output = try convert([encodedRGB.r, encodedRGB.g, encodedRGB.b])
            return try RGB64(output[0], output[1], output[2])
        case .mpetLab:
            guard sourceDeviceChannels == 3, targetDeviceChannels == 3 else {
                throw ICCRGBProfileLinkError.rgbRouteRequiresThreeChannels(
                    source: sourceDeviceChannels, target: targetDeviceChannels)
            }
            let output = try convert([encodedRGB.r, encodedRGB.g, encodedRGB.b])
            return try RGB64(output[0], output[1], output[2])
        case .traditionalXYZ, .traditionalXYZAbsolute, .traditionalLab, .traditionalLabAbsolute:
            guard sourceDeviceChannels == 3, targetDeviceChannels == 3 else {
                throw ICCRGBProfileLinkError.rgbRouteRequiresThreeChannels(
                    source: sourceDeviceChannels, target: targetDeviceChannels)
            }
            let output = try convert([encodedRGB.r, encodedRGB.g, encodedRGB.b])
            return try RGB64(output[0], output[1], output[2])
        case .lab(let source, let target):
            return try target.convert(source.convert(encodedRGB))
        case .labAbsolute(let source, let target, let scale):
            let relative = try source.toRelativePCSXYZ(encodedRGB)
            let absolute = try XYZ64(relative.x * scale.x,
                                     relative.y * scale.y,
                                     relative.z * scale.z)
            return try target.fromRelativePCSXYZ(absolute)
        }
    }

    /// Links a device sample through an arbitrary-channel `D2B`/`B2D` MPE pair.
    ///
    /// ICC MPE keeps the PCS at three channels while the device side may be
    /// one to fifteen channels.  Generic arrays are intentionally rejected for
    /// the legacy RGB-only routes so callers cannot accidentally reinterpret a
    /// device encoding or silently select a different profile path.
    public func convert(_ device: [Double]) throws -> [Double] {
        switch route {
        case .mpet(let source, let target):
            return try target.pcsXYZToDevice(try source.deviceToPCSXYZ(device))
        case .mpetLab(let source, let target):
            return try target.pcsLabToDevice(try source.deviceToPCSLab(device))
        case .traditionalXYZ(let source, let target):
            return try target.convert(source.convert(device))
        case .traditionalXYZAbsolute(let source, let target, let scale):
            let xyz = try source.convert(device)
            return try target.convert(try XYZ64(xyz.x * scale.x, xyz.y * scale.y, xyz.z * scale.z))
        case .traditionalLab(let source, let target):
            return try target.convert(source.convert(device))
        case .traditionalLabAbsolute(let source, let target, let scale):
            let relative = try source.toRelativePCSXYZ(device)
            let absolute = try XYZ64(relative.x * scale.x, relative.y * scale.y, relative.z * scale.z)
            return try target.fromRelativePCSXYZ(absolute)
        case .matrix, .lut, .lab, .labAbsolute:
            throw ICCRGBProfileLinkError.unsupportedDeviceArrayRoute
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

    private static func isDeviceProfileClass(_ profileClass: ICCProfileClass?) -> Bool {
        guard let profileClass else { return true }
        switch profileClass {
        case .inputDevice, .displayDevice, .outputDevice:
            return true
        case .deviceLink, .colorSpace, .abstract, .namedColor:
            return false
        }
    }

    private static func makeTraditionalXYZSource(profileData: Data,
                                                 profile: ICCProfileValidation,
                                                 intent: ICCMatrixTRCRenderingIntent) throws -> ICCTraditionalXYZSource {
        let tags = ICCLUTIntentTransformTags.sourceCandidates(in: profile, intent: intent)
        guard !tags.isEmpty else { throw ICCTraditionalProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.sourceName(intent)) }
        var last: ICCTraditionalProfileLinkError?
        for tag in tags {
            do {
                let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
                switch String(decoding: payload.prefix(4), as: UTF8.self) {
                case "mft2": return .mft(try ICCMFTXYZTransform(profileData: profileData, tag: tag))
                case "mAB ": return .mab(try ICCMABXYZTransform(profileData: profileData, tag: tag))
                case "mft1", "mBA ": throw ICCTraditionalProfileLinkError.unsupportedDirection
                default: throw ICCTraditionalProfileLinkError.unsupportedTagType(String(decoding: payload.prefix(4), as: UTF8.self))
                }
            } catch let error as ICCTraditionalProfileLinkError { last = error; continue }
            catch let error as ICCMFTXYZError { throw mapTraditional(error) }
            catch let error as ICCMABXYZError { throw mapTraditional(error) }
            catch { throw ICCTraditionalProfileLinkError.invalidProfile }
        }
        throw last ?? .unsupportedTagType("A2B1/A2B0")
    }

    private static func makeTraditionalXYZTarget(profileData: Data,
                                                 profile: ICCProfileValidation,
                                                 intent: ICCMatrixTRCRenderingIntent) throws -> ICCTraditionalXYZTarget {
        let tags = ICCLUTIntentTransformTags.targetCandidates(in: profile, intent: intent)
        guard !tags.isEmpty else { throw ICCTraditionalProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.targetName(intent)) }
        var last: ICCTraditionalProfileLinkError?
        for tag in tags {
            do {
                let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
                switch String(decoding: payload.prefix(4), as: UTF8.self) {
                case "mft2": return .mft(try ICCMFTXYZTransform(profileData: profileData, tag: tag))
                case "mBA ": return .mab(try ICCMABXYZTransform(profileData: profileData, tag: tag))
                case "mft1", "mAB ": throw ICCTraditionalProfileLinkError.unsupportedDirection
                default: throw ICCTraditionalProfileLinkError.unsupportedTagType(String(decoding: payload.prefix(4), as: UTF8.self))
                }
            } catch let error as ICCTraditionalProfileLinkError { last = error; continue }
            catch let error as ICCMFTXYZError { throw mapTraditional(error) }
            catch let error as ICCMABXYZError { throw mapTraditional(error) }
            catch { throw ICCTraditionalProfileLinkError.invalidProfile }
        }
        throw last ?? .unsupportedTagType("B2A1/B2A0")
    }

    private static func makeTraditionalLabSource(profileData: Data,
                                                 profile: ICCProfileValidation,
                                                 intent: ICCMatrixTRCRenderingIntent) throws -> ICCTraditionalLabSource {
        let tags = ICCLUTIntentTransformTags.sourceCandidates(in: profile, intent: intent)
        guard !tags.isEmpty else { throw ICCTraditionalProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.sourceName(intent)) }
        var last: ICCTraditionalProfileLinkError?
        for tag in tags {
            do {
                let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
                switch String(decoding: payload.prefix(4), as: UTF8.self) {
                case "mft1", "mft2": return .mft(try ICCMFTLabTransform(profileData: profileData, tag: tag))
                case "mAB ": return .mab(try ICCMABLabTransform(profileData: profileData, tag: tag))
                case "mBA ": throw ICCTraditionalProfileLinkError.unsupportedDirection
                default: throw ICCTraditionalProfileLinkError.unsupportedTagType(String(decoding: payload.prefix(4), as: UTF8.self))
                }
            } catch let error as ICCTraditionalProfileLinkError { last = error; continue }
            catch let error as ICCMFTLabError { throw mapTraditional(error) }
            catch let error as ICCMABLabError { throw mapTraditional(error) }
            catch { throw ICCTraditionalProfileLinkError.invalidProfile }
        }
        throw last ?? .unsupportedTagType("A2B1/A2B0")
    }

    private static func makeTraditionalLabTarget(profileData: Data,
                                                 profile: ICCProfileValidation,
                                                 intent: ICCMatrixTRCRenderingIntent) throws -> ICCTraditionalLabTarget {
        let tags = ICCLUTIntentTransformTags.targetCandidates(in: profile, intent: intent)
        guard !tags.isEmpty else { throw ICCTraditionalProfileLinkError.missingTransformTag(ICCLUTIntentTransformTags.targetName(intent)) }
        var last: ICCTraditionalProfileLinkError?
        for tag in tags {
            do {
                let payload = try ICCProfileValidator.payload(forTag: tag, in: profileData)
                switch String(decoding: payload.prefix(4), as: UTF8.self) {
                case "mft1", "mft2": return .mft(try ICCMFTLabTransform(profileData: profileData, tag: tag))
                case "mBA ": return .mab(try ICCMABLabTransform(profileData: profileData, tag: tag))
                case "mAB ": throw ICCTraditionalProfileLinkError.unsupportedDirection
                default: throw ICCTraditionalProfileLinkError.unsupportedTagType(String(decoding: payload.prefix(4), as: UTF8.self))
                }
            } catch let error as ICCTraditionalProfileLinkError { last = error; continue }
            catch let error as ICCMFTLabError { throw mapTraditional(error) }
            catch let error as ICCMABLabError { throw mapTraditional(error) }
            catch { throw ICCTraditionalProfileLinkError.invalidProfile }
        }
        throw last ?? .unsupportedTagType("B2A1/B2A0")
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

    private static func mediaWhitePoint(_ profile: ICCProfileValidation) throws -> XYZ64 {
        guard let tag = profile.tags.first(where: { $0.signature == "wtpt" }) else {
            throw ICCLabProfileLinkError.missingMediaWhitePoint
        }
        guard tag.typeSignature == "XYZ ", let values = tag.fixedPointValues,
              values.count == 3, values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw ICCLabProfileLinkError.malformedMediaWhitePoint
        }
        do { return try XYZ64(values[0], values[1], values[2]) }
        catch { throw ICCLabProfileLinkError.malformedMediaWhitePoint }
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

    private static func mapTraditional(_ error: ICCMFTXYZError) -> ICCTraditionalProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .unsupportedEncoding: return .unsupportedEncoding
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }

    private static func mapTraditional(_ error: ICCMABXYZError) -> ICCTraditionalProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .unsupportedEncoding: return .unsupportedEncoding
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }

    private static func mapTraditional(_ error: ICCMFTLabError) -> ICCTraditionalProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }

    private static func mapTraditional(_ error: ICCMABLabError) -> ICCTraditionalProfileLinkError {
        switch error {
        case .invalidProfile: return .invalidProfile
        case .unsupportedColorSpace: return .unsupportedColorSpace
        case .unsupportedPCS: return .unsupportedPCS
        case .unsupportedDirection: return .unsupportedDirection
        case .transform, .outsideDomain, .nonFinite: return .invalidProfile
        }
    }
}
