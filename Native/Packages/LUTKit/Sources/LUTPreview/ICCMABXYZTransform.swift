import Foundation
import LUTCore

public enum ICCMABXYZError: Error, Equatable, Sendable {
    case invalidProfile
    case unsupportedColorSpace
    case unsupportedPCS
    case unsupportedDirection
    case unsupportedEncoding
    case transform(ICCMABError)
    case outsideDomain
    case nonFinite
}

/// Bounded RGB↔PCS XYZ adapters for user supplied 16-bit `mAB`/`mBA` tags.
/// An 8-bit CLUT cannot carry the ICC PCSXYZ integer encoding and is rejected.
public struct ICCMABXYZTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMABTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "B2A0", "B2A1"].contains(tag) else {
            throw ICCMABXYZError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do { profile = try ICCProfileValidator.validate(profileData) }
        catch { throw ICCMABXYZError.invalidProfile }
        guard profile.colorSpaceSignature == "RGB " else {
            throw ICCMABXYZError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "XYZ " else {
            throw ICCMABXYZError.unsupportedPCS
        }
        do {
            let parsed = try ICCMABTransform(profileData: profileData, tag: tag)
            if let bytes = parsed.clutBytesPerSample, bytes != 2 {
                throw ICCMABXYZError.unsupportedEncoding
            }
            transform = parsed
        } catch let error as ICCMABXYZError {
            throw error
        } catch let error as ICCMABError {
            throw ICCMABXYZError.transform(error)
        } catch {
            throw ICCMABXYZError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToXYZ(_ rgb: RGB64) throws -> XYZ64 {
        guard direction == .aToB else { throw ICCMABXYZError.unsupportedDirection }
        do {
            let encoded = try transform.sample(rgb)
            return try ICCXYZPCS.decodeNormalized([encoded.r, encoded.g, encoded.b])
        } catch let error as ICCMABError {
            throw ICCMABXYZError.transform(error)
        } catch let error as ICCXYZPCS.Error {
            throw error == .nonFinite ? ICCMABXYZError.nonFinite : ICCMABXYZError.outsideDomain
        } catch {
            throw ICCMABXYZError.invalidProfile
        }
    }

    public func xyzToRGB(_ xyz: XYZ64) throws -> RGB64 {
        guard direction == .bToA else { throw ICCMABXYZError.unsupportedDirection }
        do {
            let values = try ICCXYZPCS.encodeNormalized(xyz)
            return try transform.sample(try RGB64(values[0], values[1], values[2]))
        } catch let error as ICCMABError {
            throw ICCMABXYZError.transform(error)
        } catch let error as ICCXYZPCS.Error {
            throw error == .nonFinite ? ICCMABXYZError.nonFinite : ICCMABXYZError.outsideDomain
        } catch {
            throw ICCMABXYZError.invalidProfile
        }
    }
}
