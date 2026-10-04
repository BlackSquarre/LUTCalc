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
/// The underlying LUT pipeline remains the existing three-channel CPU parser;
/// this adapter only interprets its continuous unsigned PCS values according
/// to ICC.1:2022-05 and converts them through the D50 CIELAB implementation.
/// It accepts only RGB profiles whose PCS signature is `Lab ` and only the
/// explicit A2B/B2A directions.
public struct ICCMABLabTransform: Sendable {
    private enum Direction: Sendable { case aToB, bToA }

    private let transform: ICCMABTransform
    private let direction: Direction

    public init(profileData: Data, tag: String) throws {
        guard ["A2B0", "A2B1", "B2A0", "B2A1"].contains(tag) else {
            throw ICCMABLabError.unsupportedDirection
        }
        let profile: ICCProfileValidation
        do {
            profile = try ICCProfileValidator.validate(profileData)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        guard profile.colorSpaceSignature == "RGB " else {
            throw ICCMABLabError.unsupportedColorSpace
        }
        guard profile.pcsSignature == "Lab " else {
            throw ICCMABLabError.unsupportedPCS
        }
        do {
            transform = try ICCMABTransform(profileData: profileData, tag: tag)
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        direction = tag.hasPrefix("A2B") ? .aToB : .bToA
    }

    public func rgbToLab(_ rgb: RGB64) throws -> CIELABColor {
        guard direction == .aToB else { throw ICCMABLabError.unsupportedDirection }
        let encoded: RGB64
        do {
            encoded = try transform.sample(rgb)
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
        do {
            return try ICCLabPCS.decodeNormalized([encoded.r, encoded.g, encoded.b])
        } catch let error as ICCLabPCS.Error {
            switch error {
            case .nonFinite: throw ICCMABLabError.nonFinite
            default: throw ICCMABLabError.outsideDomain
            }
        }
    }

    public func labToRGB(_ lab: CIELABColor) throws -> RGB64 {
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
            return try transform.sample(try RGB64(values[0], values[1], values[2]))
        } catch let error as ICCMABError {
            throw ICCMABLabError.transform(error)
        } catch {
            throw ICCMABLabError.invalidProfile
        }
    }
}
