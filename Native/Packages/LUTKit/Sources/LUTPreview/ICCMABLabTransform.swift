import Foundation
import LUTCore

public enum ICCMABLabError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedDirection
    case transform(ICCMABError)
    case outsideDomain
    case nonFinite
}

/// Bounded RGB↔PCS Lab adapters for user supplied ICC `mAB`/`mBA` tags.
///
/// This adapter interprets continuous unsigned PCS values according to
/// ICC.1:2022-05 and converts them through the D50 CIELAB implementation.
public struct ICCMABLabTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMABTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "A2B2", "A2B3", "B2A0", "B2A1", "B2A2", "B2A3"].contains(tag) else {
            throw ICCMABLabError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        guard let deviceChannels = profile.colorChannelCount,
              (1...15).contains(deviceChannels) else {
            throw ICCMABLabError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "Lab " else {
            throw ICCMABLabError.unsupportedPCS
        }
        do {
            transform = try ICCMABTransform(profileData: profileData, tag: tag)
            let expectedInput = tag.hasPrefix("A2B") ? deviceChannels : 3
            let expectedOutput = tag.hasPrefix("A2B") ? 3 : deviceChannels
            guard transform.inputChannels == expectedInput,
                  transform.outputChannels == expectedOutput else {
                throw ICCMABError.unsupportedChannels
            }
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToLab(_ rgb: RGB64) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMABLabError.unsupportedDirection }
        return try deviceToLab([rgb.r, rgb.g, rgb.b])
    }

    /// Converts an arbitrary-channel device sample to PCS Lab.
    public func deviceToLab(_ device: [Double]) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMABLabError.unsupportedDirection }
        let encoded: [Double]
        do {
            encoded = try transform.sample(device)
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        do {
            return try ICCLabPCS.decodeNormalized(encoded)
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMABLabError.nonFinite
            default: throw ICCMABLabError.outsideDomain
            }
        }
    }

    public func labToRGB(_ lab: CIELABColor) throws -> RGB64 {
        guard direction == .bToA else { throw ICCMABLabError.unsupportedDirection }
        let values = try labToDevice(lab)
        return try RGB64(values[0], values[1], values[2])
    }

    /// Converts PCS Lab to an arbitrary-channel device sample.
    public func labToDevice(_ lab: CIELABColor) throws -> [Double] {
        guard direction == .bToA else { throw ICCMABLabError.unsupportedDirection }
        let values: [Double]
        do {
            values = try ICCLabPCS.encodeNormalized(lab)
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMABLabError.nonFinite
            default: throw ICCMABLabError.outsideDomain
            }
        }
        do {
            return try transform.sample(values)
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
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
