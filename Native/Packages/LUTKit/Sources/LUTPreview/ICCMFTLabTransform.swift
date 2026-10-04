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

/// Bounded RGB↔PCS Lab adapters for user supplied ICC `mft1`/`mft2` tags.
/// Only three-channel RGB profiles with explicit A2B/B2A direction are
/// accepted; continuous unsigned PCS values use the ICC D50 Lab definition.
public struct ICCMFTLabTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMFTTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "B2A0", "B2A1"].contains(tag) else {
            throw ICCMFTLabError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        guard profile.colorSpaceSignature == "RGB " else {
            throw ICCMFTLabError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "Lab " else {
            throw ICCMFTLabError.unsupportedPCS
        }
        do {
            transform = try ICCMFTTransform(profileData: profileData, tag: tag)
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToLab(_ rgb: RGB64) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMFTLabError.unsupportedDirection }
        let encoded: RGB64
        do {
            encoded = try transform.sample(rgb)
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
        do {
            return try ICCLabPCS.decodeNormalized([encoded.r, encoded.g, encoded.b])
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMFTLabError.nonFinite
            default: throw ICCMFTLabError.outsideDomain
            }
        }
    }

    public func labToRGB(_ lab: CIELABColor) throws -> RGB64 {
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
            return try transform.sample(try RGB64(values[0], values[1], values[2]))
        } catch let error as ICCMFTError {
            throw ICCMFTLabError.transform(error)
        } catch {
            throw ICCMFTLabError.invalidProfile
        }
    }
}
