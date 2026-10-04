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

/// Bounded RGB↔PCS XYZ adapters for user supplied ICC `mft2` tags.
/// ICC defines no 8-bit PCSXYZ encoding, so `mft1` is rejected explicitly.
public struct ICCMFTXYZTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMFTTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "B2A0", "B2A1"].contains(tag) else {
            throw ICCMFTXYZError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do { profile = try ICCProfileValidator.validate(profileData) }
        catch { throw ICCMFTXYZError.invalidProfile }
        guard profile.colorSpaceSignature == "RGB " else {
            throw ICCMFTXYZError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "XYZ " else {
            throw ICCMFTXYZError.unsupportedPCS
        }
        do {
            let parsed = try ICCMFTTransform(profileData: profileData, tag: tag)
            guard parsed.sampleBytes == 2 else { throw ICCMFTXYZError.unsupportedEncoding }
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
        do {
            let encoded = try transform.sample(rgb)
            return try ICCXYZPCS.decodeNormalized([encoded.r, encoded.g, encoded.b])
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
        do {
            let values = try ICCXYZPCS.encodeNormalized(xyz)
            return try transform.sample(try RGB64(values[0], values[1], values[2]))
        } catch let error as ICCMFTError {
            throw ICCMFTXYZError.transform(error)
        } catch let error as ICCXYZPCS.Error {
            throw error == .nonFinite ? ICCMFTXYZError.nonFinite : ICCMFTXYZError.outsideDomain
        } catch {
            throw ICCMFTXYZError.invalidProfile
        }
    }
}
