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

    /// CIE 1976 Delta E*ab, with normalized L* converted to the standard 0...100
    /// scale before the Euclidean distance is evaluated. This metric does not
    /// perform white-point adaptation or gamut handling; callers must compare
    /// colors produced under the same Lab conditions.
    public func deltaE76(to other: CIELABColor) -> Double {
        let deltaL = (lStar - other.lStar) * 100.0
        let deltaA = aStar - other.aStar
        let deltaB = bStar - other.bStar
        return (deltaL * deltaL + deltaA * deltaA + deltaB * deltaB).squareRoot()
    }

    /// CIE94 color difference. The first color supplies the reference chroma
    /// for the chroma and hue weighting terms, as specified by CIE 116-1995.
    public func deltaE94(to other: CIELABColor,
                         application: CIELABDeltaE94Application = .graphicArts) -> Double {
        let l1 = lStar * 100.0
        let l2 = other.lStar * 100.0
        let c1 = (aStar * aStar + bStar * bStar).squareRoot()
        let c2 = (other.aStar * other.aStar + other.bStar * other.bStar).squareRoot()
        let deltaL = l2 - l1
        let deltaC = c2 - c1
        let deltaA = other.aStar - aStar
        let deltaB = other.bStar - bStar
        let deltaH2 = max(0.0, deltaA * deltaA + deltaB * deltaB - deltaC * deltaC)
        let lightness = deltaL / (application.lightnessFactor * application.lightnessScale)
        let chroma = deltaC / (application.chromaFactor
            * (1.0 + application.chromaScale * c1))
        let hue = deltaH2.squareRoot() / (application.hueFactor
            * (1.0 + application.hueScale * c1))
        return (lightness * lightness + chroma * chroma + hue * hue).squareRoot()
    }

    /// CIEDE2000, using the normalized L* storage only as an internal
    /// representation. The metric is defined for colors measured under the
    /// same Lab white point and viewing conditions; it does not perform
    /// adaptation, gamut mapping, or clipping.
    public func deltaE2000(to other: CIELABColor) -> Double {
        let l1 = lStar * 100.0
        let l2 = other.lStar * 100.0
        let a1 = aStar
        let a2 = other.aStar
        let b1 = bStar
        let b2 = other.bStar

        let c1 = (a1 * a1 + b1 * b1).squareRoot()
        let c2 = (a2 * a2 + b2 * b2).squareRoot()
        let meanC = (c1 + c2) / 2.0
        let meanC7 = meanC * meanC * meanC * meanC * meanC * meanC * meanC
        let twentyFive7 = 25.0 * 25.0 * 25.0 * 25.0 * 25.0 * 25.0 * 25.0
        let g = 0.5 * (1.0 - (meanC7 / (meanC7 + twentyFive7)).squareRoot())
        let a1Prime = (1.0 + g) * a1
        let a2Prime = (1.0 + g) * a2
        let c1Prime = (a1Prime * a1Prime + b1 * b1).squareRoot()
        let c2Prime = (a2Prime * a2Prime + b2 * b2).squareRoot()

        func hueDegrees(a: Double, b: Double, chroma: Double) -> Double {
            guard chroma > 0.0 else { return 0.0 }
            let degrees = Foundation.atan2(b, a) * 180.0 / Double.pi
            return degrees >= 0.0 ? degrees : degrees + 360.0
        }

        let h1Prime = hueDegrees(a: a1Prime, b: b1, chroma: c1Prime)
        let h2Prime = hueDegrees(a: a2Prime, b: b2, chroma: c2Prime)
        let deltaL = l2 - l1
        let deltaC = c2Prime - c1Prime
        let chromaProduct = c1Prime * c2Prime
        let deltaHue: Double
        if chromaProduct == 0.0 {
            deltaHue = 0.0
        } else {
            let raw = h2Prime - h1Prime
            if abs(raw) <= 180.0 {
                deltaHue = raw
            } else if raw > 180.0 {
                deltaHue = raw - 360.0
            } else {
                deltaHue = raw + 360.0
            }
        }
        let deltaBigH = 2.0 * chromaProduct.squareRoot()
            * Foundation.sin(deltaHue * Double.pi / 360.0)

        let meanL = (l1 + l2) / 2.0
        let meanCPrime = (c1Prime + c2Prime) / 2.0
        let meanHue: Double
        if chromaProduct == 0.0 {
            meanHue = h1Prime + h2Prime
        } else {
            let raw = h1Prime + h2Prime
            let difference = abs(h1Prime - h2Prime)
            if difference <= 180.0 {
                meanHue = raw / 2.0
            } else if raw < 360.0 {
                meanHue = (raw + 360.0) / 2.0
            } else {
                meanHue = (raw - 360.0) / 2.0
            }
        }

        let meanHueRadians = meanHue * Double.pi / 180.0
        let t = 1.0
            - 0.17 * Foundation.cos(meanHueRadians - 30.0 * Double.pi / 180.0)
            + 0.24 * Foundation.cos(2.0 * meanHueRadians)
            + 0.32 * Foundation.cos(3.0 * meanHueRadians + 6.0 * Double.pi / 180.0)
            - 0.20 * Foundation.cos(4.0 * meanHueRadians - 63.0 * Double.pi / 180.0)
        let hueOffset = (meanHue - 275.0) / 25.0
        let deltaTheta = 30.0 * Foundation.exp(-(hueOffset * hueOffset))
        let meanCPrime7 = meanCPrime * meanCPrime * meanCPrime * meanCPrime
            * meanCPrime * meanCPrime * meanCPrime
        let rc = 2.0 * (meanCPrime7 / (meanCPrime7 + twentyFive7)).squareRoot()
        let lightnessOffset = meanL - 50.0
        let lightnessOffset2 = lightnessOffset * lightnessOffset
        let sl = 1.0 + (0.015 * lightnessOffset2)
            / (20.0 + lightnessOffset2).squareRoot()
        let sc = 1.0 + 0.045 * meanCPrime
        let sh = 1.0 + 0.015 * meanCPrime * t
        let rt = -Foundation.sin(2.0 * deltaTheta * Double.pi / 180.0) * rc

        let lightnessTerm = deltaL / sl
        let chromaTerm = deltaC / sc
        let hueTerm = deltaBigH / sh
        return (lightnessTerm * lightnessTerm
            + chromaTerm * chromaTerm
            + hueTerm * hueTerm
            + rt * chromaTerm * hueTerm).squareRoot()
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

/// CIE94 weighting presets for the two published application domains.
public enum CIELABDeltaE94Application: String, Codable, Sendable {
    case graphicArts
    case textiles

    fileprivate var lightnessFactor: Double {
        switch self {
        case .graphicArts: return 1.0
        case .textiles: return 2.0
        }
    }

    fileprivate var chromaFactor: Double { 1.0 }
    fileprivate var hueFactor: Double { 1.0 }

    fileprivate var lightnessScale: Double { 1.0 }

    fileprivate var chromaScale: Double {
        switch self {
        case .graphicArts: return 0.045
        case .textiles: return 0.048
        }
    }

    fileprivate var hueScale: Double {
        switch self {
        case .graphicArts: return 0.015
        case .textiles: return 0.014
        }
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
