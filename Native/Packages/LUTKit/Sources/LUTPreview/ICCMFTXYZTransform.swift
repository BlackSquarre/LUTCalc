import Foundation
import LUTCore

public enum ICCMFTXYZError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedDirection
    case unsupportedEncoding
    case transform(ICCMFTError)
    case outsideDomain
    case nonFinite
}

/// Bounded device↔PCS XYZ adapters for user supplied ICC `mft2` tags.
/// ICC defines no 8-bit PCSXYZ encoding, so `mft1` is rejected explicitly.
public struct ICCMFTXYZTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMFTTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "A2B2", "A2B3", "B2A0", "B2A1", "B2A2", "B2A3"].contains(tag) else {
            throw ICCMFTXYZError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do { profile = try ICCProfileValidator.validate(profileData) }
        catch { throw ICCMFTXYZError.invalidProfile }
        guard let deviceChannels = profile.colorChannelCount,
              (1...15).contains(deviceChannels) else {
            throw ICCMFTXYZError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "XYZ " else {
            throw ICCMFTXYZError.unsupportedPCS
        }
        do {
            let parsed = try ICCMFTTransform(profileData: profileData, tag: tag)
            guard parsed.sampleBytes == 2 else { throw ICCMFTXYZError.unsupportedEncoding }
            let expectedInput = tag.hasPrefix("A2B") ? deviceChannels : 3
            let expectedOutput = tag.hasPrefix("A2B") ? 3 : deviceChannels
            guard parsed.inputChannels == expectedInput, parsed.outputChannels == expectedOutput else {
                throw ICCMFTXYZError.unsupportedColorSpace
            }
            transform = parsed
        } catch let error as ICCMFTXYZError {
            throw error
        } catch let error as ICCMFTError {
            throw ICCMFTXYZError.transform(error)
        } catch {
            throw ICCMFTXYZError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToXYZ(_ rgb: RGB64) throws -> XYZ64 {
        guard direction == .aToB else { throw ICCMFTXYZError.unsupportedDirection }
        let values = try deviceToXYZ([rgb.r, rgb.g, rgb.b])
        return values
    }

    /// Converts an arbitrary-channel device sample to PCS XYZ.
    public func deviceToXYZ(_ device: [Double]) throws -> XYZ64 {
        guard direction == .aToB else { throw ICCMFTXYZError.unsupportedDirection }
        do {
            let encoded = try transform.sample(device)
            return try ICCXYZPCS.decodeNormalized(encoded)
        } catch let error as ICCMFTError {
            throw ICCMFTXYZError.transform(error)
        } catch let error as ICCXYZPCS.Error {
            throw error == .nonFinite ? ICCMFTXYZError.nonFinite : ICCMFTXYZError.outsideDomain
        } catch {
            throw ICCMFTXYZError.invalidProfile
        }
    }

    public func xyzToRGB(_ xyz: XYZ64) throws -> RGB64 {
        guard direction == .bToA else { throw ICCMFTXYZError.unsupportedDirection }
        let values = try xyzToDevice(xyz)
        return try RGB64(values[0], values[1], values[2])
    }

    /// Converts PCS XYZ to an arbitrary-channel device sample.
    public func xyzToDevice(_ xyz: XYZ64) throws -> [Double] {
        guard direction == .bToA else { throw ICCMFTXYZError.unsupportedDirection }
        do {
            let values = try ICCXYZPCS.encodeNormalized(xyz)
            return try transform.sample(values)
        } catch let error as ICCMFTError {
            throw ICCMFTXYZError.transform(error)
        } catch let error as ICCXYZPCS.Error {
            throw error == .nonFinite ? ICCMFTXYZError.nonFinite : ICCMFTXYZError.outsideDomain
        } catch {
            throw ICCMFTXYZError.invalidProfile
        }
    }
}
