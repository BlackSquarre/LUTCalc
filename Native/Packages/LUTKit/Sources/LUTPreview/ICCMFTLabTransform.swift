import Foundation
import LUTCore

public enum ICCMFTLabError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedDirection
    case transform(ICCMFTError)
    case outsideDomain
    case nonFinite
}

/// Bounded device↔PCS Lab adapters for user supplied ICC `mft1`/`mft2` tags.
/// Continuous unsigned PCS values use the ICC D50 Lab definition.
public struct ICCMFTLabTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMFTTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "A2B2", "A2B3", "B2A0", "B2A1", "B2A2", "B2A3"].contains(tag) else {
            throw ICCMFTLabError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        guard let deviceChannels = profile.colorChannelCount,
              (1...15).contains(deviceChannels) else {
            throw ICCMFTLabError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "Lab " else {
            throw ICCMFTLabError.unsupportedPCS
        }
        do {
            transform = try ICCMFTTransform(profileData: profileData, tag: tag)
            let expectedInput = tag.hasPrefix("A2B") ? deviceChannels : 3
            let expectedOutput = tag.hasPrefix("A2B") ? 3 : deviceChannels
            guard transform.inputChannels == expectedInput,
                  transform.outputChannels == expectedOutput else {
                throw ICCMFTError.unsupportedChannels
            }
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToLab(_ rgb: RGB64) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMFTLabError.unsupportedDirection }
        return try deviceToLab([rgb.r, rgb.g, rgb.b])
    }

    /// Converts an arbitrary-channel device sample to PCS Lab.
    public func deviceToLab(_ device: [Double]) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMFTLabError.unsupportedDirection }
        let encoded: [Double]
        do {
            encoded = try transform.sample(device)
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        do {
            return try ICCLabPCS.decodeNormalized(encoded)
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMFTLabError.nonFinite
            default: throw ICCMFTLabError.outsideDomain
            }
        }
    }

    public func labToRGB(_ lab: CIELABColor) throws -> RGB64 {
        guard direction == .bToA else { throw ICCMFTLabError.unsupportedDirection }
        let values = try labToDevice(lab)
        return try RGB64(values[0], values[1], values[2])
    }

    /// Converts PCS Lab to an arbitrary-channel device sample.
    public func labToDevice(_ lab: CIELABColor) throws -> [Double] {
        guard direction == .bToA else { throw ICCMFTLabError.unsupportedDirection }
        let values: [Double]
        do {
            values = try ICCLabPCS.encodeNormalized(lab)
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMFTLabError.nonFinite
            default: throw ICCMFTLabError.outsideDomain
            }
        }
        do {
            return try transform.sample(values)
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
    }

    /// Converts a media-relative PCS Lab result to the normalized PCS XYZ
    /// representation used by ICC absolute colorimetric scaling.
    public func rgbToRelativePCSXYZ(_ rgb: RGB64) throws -> XYZ64 {
        try deviceToLab([rgb.r, rgb.g, rgb.b]).toXYZ(white: .d50)
    }

    /// Converts a media-relative PCS XYZ value through this profile's Lab
    /// encoding back to device RGB.
    public func relativePCSXYZToRGB(_ xyz: XYZ64) throws -> RGB64 {
        try labToRGB(CIELABColorSpace.fromXYZ(xyz, white: .d50))
    }
}
