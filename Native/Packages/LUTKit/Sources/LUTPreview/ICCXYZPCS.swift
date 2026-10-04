import Foundation
import LUTCore

/// ICC.1:2022-05 §6.3.4 PCSXYZ integer encoding used by 16-bit LUT tags.
/// The u1Fixed15 representation maps an encoded 0...1 table value to
/// `value * 65535 / 32768`; no clipping or implicit repair is performed.
public enum ICCXYZPCS {
    public static let referenceURL = "ICC.1:2022-05 §6.3.4.2 Table 11"
    public static let maximum = 65535.0 / 32768.0

    public enum Error: Swift.Error, Equatable, Sendable {
        case malformedEncoding
        case outsideDomain
        case nonFinite
    }

    public static func decodeNormalized(_ values: [Double]) throws -> XYZ64 {
        guard values.count == 3 else { throw Error.malformedEncoding }
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw Error.outsideDomain
        }
        return try XYZ64(values[0] * maximum, values[1] * maximum, values[2] * maximum)
    }

    public static func encodeNormalized(_ xyz: XYZ64) throws -> [Double] {
        let values = [xyz.x, xyz.y, xyz.z]
        guard values.allSatisfy(\.isFinite) else { throw Error.nonFinite }
        guard values.allSatisfy({ (0...maximum).contains($0) }) else {
            throw Error.outsideDomain
        }
        return values.map { $0 / maximum }
    }
}
