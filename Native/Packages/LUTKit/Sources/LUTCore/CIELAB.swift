import Foundation

/// CIE 1931 XYZ tristimulus values normalized so the reference white has Y = 1.
/// Values remain unbounded to preserve negative and over-white scene samples.
public struct XYZ64: Equatable, Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) throws {
        guard x.isFinite, y.isFinite, z.isFinite else { throw NumericError.nonFinite }
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Reference whites used by the legacy CIELAB entries and the native pre-contract.
/// The normalized XYZ values retain the published LUTCalc constants exactly.
public enum CIELABWhitePoint: String, Codable, Sendable {
    case d50
    case d65

    public var xyz: XYZ64 {
        switch self {
        case .d50: try! XYZ64(0.964212, 1.0, 0.825188)
        case .d65: try! XYZ64(0.950489, 1.0, 1.088840)
        }
    }
}

/// Normalized CIELAB values. L* is represented on 0...1 for compatibility with
/// the native CIE L* transfer; a* and b* retain their conventional unbounded units.
public struct CIELABColor: Equatable, Hashable, Codable, Sendable {
    public let lStar: Double
    public let aStar: Double
    public let bStar: Double

    public init(lStar: Double, aStar: Double, bStar: Double) throws {
        guard lStar.isFinite, aStar.isFinite, bStar.isFinite else {
            throw NumericError.nonFinite
        }
        self.lStar = lStar
        self.aStar = aStar
        self.bStar = bStar
    }

    public func toXYZ(white: CIELABWhitePoint) throws -> XYZ64 {
        let fy = (lStar + CIELABColorSpace.lStarOffset) / CIELABColorSpace.lStarScale
        let fx = fy + aStar / 5.0
        let fz = fy - bStar / 2.0
        let xr = CIELABColorSpace.inverseFunction(fx)
        let yr = CIELABColorSpace.inverseFunction(fy)
        let zr = CIELABColorSpace.inverseFunction(fz)
        return try XYZ64(
            xr * white.xyz.x,
            yr * white.xyz.y,
            zr * white.xyz.z
        )
    }
}

/// Analytic CIELAB conversion using the CIE/ISO piecewise function.
/// This type deliberately remains outside ColorSpaceID/TransformPlan until a
/// non-matrix Lab pipeline and its persistence contract are frozen.
public enum CIELABColorSpace {
    public static let referenceURL = "ISO 11664-4; ITU-R BT.2380-0 §3.3"
    public static let linearCut = 216.0 / 24389.0
    public static let encodedCut = 216.0 / 2700.0
    private static let fCut = 6.0 / 29.0
    public static let lStarScale = 1.16
    public static let lStarOffset = 0.16
    private static let slope = 24389.0 / 2700.0

    public static func fromXYZ(_ xyz: XYZ64, white: CIELABWhitePoint) throws -> CIELABColor {
        let xr = xyz.x / white.xyz.x
        let yr = xyz.y / white.xyz.y
        let zr = xyz.z / white.xyz.z
        guard xr.isFinite, yr.isFinite, zr.isFinite else { throw NumericError.nonFinite }
        let fx = forwardFunction(xr)
        let fy = forwardFunction(yr)
        let fz = forwardFunction(zr)
        return try CIELABColor(
            lStar: lStarScale * fy - lStarOffset,
            aStar: 5.0 * (fx - fy),
            bStar: 2.0 * (fy - fz)
        )
    }

    private static func forwardFunction(_ value: Double) -> Double {
        if value >= linearCut {
            return value.cbrt
        }
        return (slope * value + lStarOffset) / lStarScale
    }

    fileprivate static func inverseFunction(_ value: Double) -> Double {
        if value >= fCut {
            return value * value * value
        }
        return (lStarScale * value - lStarOffset) / slope
    }
}

private extension Double {
    var cbrt: Double {
        if self < 0 { return -Foundation.pow(-self, 1.0 / 3.0) }
        return Foundation.pow(self, 1.0 / 3.0)
    }
}
