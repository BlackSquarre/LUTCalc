import Foundation
import LUTCore

/// Errors for the bounded ICC device-link execution path.
public enum ICCDeviceLinkError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedProfileClass
    case unsupportedColorSpace
    case unsupportedPCS
    case headerIntentMismatch(header: ICCMatrixTRCRenderingIntent,
                              requested: ICCMatrixTRCRenderingIntent)
    case missingA2B0
    case unsupportedTagType(String)
    case unsupportedDirection
    case dimensionMismatch
    case transform
}

/// Executes the single, profile-declared `A2B0` transform of an ICC device-link
/// profile. ICC.1:2022-05 §7.2.3 and §9.2.1 define the device-link data and
/// output color-space fields and select the link intent from the profile
/// header. No intent fallback or implicit PCS conversion is performed.
public struct ICCDeviceLinkTransform: Sendable {
    private enum Route: Sendable {
        case mft(ICCMFTTransform)
        case mab(ICCMABTransform)
        case mpet(ICCMPETransform)

        func sample(_ values: [Double]) throws -> [Double] {
            switch self {
            case .mft(let transform): return try transform.sample(values)
            case .mab(let transform): return try transform.sample(values)
            case .mpet(let transform): return try transform.sample(values)
            }
        }
    }

    public let intent: ICCMatrixTRCRenderingIntent
    public let inputChannels: Int
    public let outputChannels: Int
    private let route: Route

    public init(profileData: Data,
                intent requestedIntent: ICCMatrixTRCRenderingIntent? = nil) throws {
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCDeviceLinkError.invalidProfile
        }
        guard profile.profileClass == .deviceLink else {
            throw ICCDeviceLinkError.unsupportedProfileClass
        }
        guard let inputChannels = profile.colorChannelCount,
              let outputChannels = ICCDeviceLinkTransform.channelCount(for: profile.pcsSignature),
              (1...15).contains(inputChannels),
              (1...15).contains(outputChannels) else {
            throw ICCDeviceLinkError.unsupportedColorSpace
        }
        let headerIntent: ICCMatrixTRCRenderingIntent
        guard let parsedIntent = ICCMatrixTRCRenderingIntent(rawValue: profile.renderingIntent) else {
            throw ICCDeviceLinkError.unsupportedPCS
        }
        headerIntent = parsedIntent
        if let requestedIntent, requestedIntent != headerIntent {
            throw ICCDeviceLinkError.headerIntentMismatch(header: headerIntent,
                                                          requested: requestedIntent)
        }
        guard profile.tagSignatures.contains("A2B0") else {
            throw ICCDeviceLinkError.missingA2B0
        }

        let payload: Data
        do {
            payload = try ICCProfileValidator.payload(forTag: "A2B0", in: profileData)
        } catch {
            throw ICCDeviceLinkError.missingA2B0
        }
        let type = String(decoding: payload.prefix(4), as: UTF8.self)
        do {
            switch type {
            case "mft1", "mft2":
                // mft payloads declare device channel counts in the tag
                // header. Report a profile dimension mismatch before the
                // lower-level parser reports malformed channel semantics.
                guard payload.count >= 10 else {
                    throw ICCDeviceLinkError.transform
                }
                let declaredInputChannels = Int(payload[payload.startIndex + 8])
                let declaredOutputChannels = Int(payload[payload.startIndex + 9])
                guard declaredInputChannels == inputChannels,
                      declaredOutputChannels == outputChannels else {
                    throw ICCDeviceLinkError.dimensionMismatch
                }
                let transform = try ICCMFTTransform(profileData: profileData, tag: "A2B0")
                guard transform.inputChannels == inputChannels,
                      transform.outputChannels == outputChannels else {
                    throw ICCDeviceLinkError.dimensionMismatch
                }
                route = .mft(transform)
            case "mAB ":
                let transform = try ICCMABTransform(profileData: profileData, tag: "A2B0")
                guard transform.inputChannels == inputChannels,
                      transform.outputChannels == outputChannels else {
                    throw ICCDeviceLinkError.dimensionMismatch
                }
                route = .mab(transform)
            case "mpet":
                let transform = try ICCMPETransform(profileData: profileData,
                                                    tag: "A2B0",
                                                    deviceLinkOutputChannels: outputChannels)
                guard transform.inputChannels == inputChannels,
                      transform.outputChannels == outputChannels else {
                    throw ICCDeviceLinkError.dimensionMismatch
                }
                route = .mpet(transform)
            case "mBA ":
                throw ICCDeviceLinkError.unsupportedDirection
            default:
                throw ICCDeviceLinkError.unsupportedTagType(type)
            }
        } catch let error as ICCDeviceLinkError {
            throw error
        } catch {
            throw ICCDeviceLinkError.transform
        }
        self.intent = headerIntent
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
    }

    public func sample(_ input: [Double]) throws -> [Double] {
        guard input.count == inputChannels,
              input.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw ICCDeviceLinkError.dimensionMismatch
        }
        return try route.sample(input)
    }

    public func sample(_ input: RGB64) throws -> RGB64 {
        guard inputChannels == 3, outputChannels == 3 else {
            throw ICCDeviceLinkError.dimensionMismatch
        }
        let output = try sample([input.r, input.g, input.b])
        return try RGB64(output[0], output[1], output[2])
    }

    private static func channelCount(for signature: String) -> Int? {
        switch signature {
        case "GRAY": return 1
        case "RGB ", "XYZ ", "Lab ", "Luv ", "YCbr", "Yxy ", "HSV ", "HLS ", "CMY ":
            return 3
        case "CMYK": return 4
        default:
            guard signature.count == 4, signature.hasSuffix("CLR"),
                  let scalar = signature.unicodeScalars.first else { return nil }
            switch scalar.value {
            case 0x32...0x39: return Int(scalar.value - 0x30)
            case 0x41...0x46: return Int(scalar.value - 0x41 + 10)
            default: return nil
            }
        }
    }
}
