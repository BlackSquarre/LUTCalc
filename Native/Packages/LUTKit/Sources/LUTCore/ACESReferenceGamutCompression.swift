import Foundation

public enum ACESReferenceGamutCompressionError: Error, Equatable, Sendable {
    case nonFinite
    case nonInvertible
}

/// Persisted selection for the ACES 1.3 reference gamut compression stage.
/// The stage is deliberately restricted to linear ACES AP0 plans; it is not
/// the legacy output gamut limiter.
public struct ACESReferenceGamutCompressionSettings: Equatable, Codable, Sendable {
    public enum Operation: String, Codable, Sendable {
        case compress
        case decompress
    }

    public static let algorithm = ACESReferenceGamutCompression.algorithm
    public let algorithm: String
    public let enabled: Bool
    public let operation: Operation

    public init(enabled: Bool = true,
                operation: Operation = .compress,
                algorithm: String = ACESReferenceGamutCompression.algorithm) {
        self.algorithm = algorithm
        self.enabled = enabled
        self.operation = operation
    }

    public func makeKernel() throws -> ACESReferenceGamutCompression {
        guard algorithm == Self.algorithm else { throw NumericError.invalidDomain }
        return ACESReferenceGamutCompression()
    }
}

/// ACES 1.3 Reference Gamut Compression applied to linear ACES 2065-1 RGB.
/// This is the published static operator; it is not the application's legacy limiter.
public struct ACESReferenceGamutCompression: Equatable, Sendable {
    public static let algorithm = "aces.reference-gamut-compression-1.3.0"
    public static let transformID = "urn:ampas:aces:transformId:v1.5:LMT.Academy.GamutCompress.a1.3.0"
    public static let referenceURL = "research/colour/2026-09-23/pages/aces-rgc.html"

    public static let ap0ToAp1: Matrix3x3 = try! Matrix3x3(rowMajor: [
        1.4514393161, -0.2365107469, -0.2149285693,
        -0.0765537734, 1.1762296998, -0.0996759264,
        0.0083161484, -0.0060324498, 0.9977163014,
    ])

    public static let ap1ToAp0: Matrix3x3 = try! Matrix3x3(rowMajor: [
        0.6954522414, 0.1406786965, 0.1638690622,
        0.0447945634, 0.8596711185, 0.0955343182,
        -0.0055258826, 0.0040252103, 1.0015006723,
    ])

    public static let limits = (r: 1.147, g: 1.264, b: 1.312)
    public static let thresholds = (r: 0.815, g: 0.803, b: 0.880)
    public static let exponent = 1.2

    public init() {}

    public func compress(_ input: RGB64) throws -> RGB64 {
        guard input.r.isFinite, input.g.isFinite, input.b.isFinite else {
            throw ACESReferenceGamutCompressionError.nonFinite
        }
        let ap1 = try Self.ap0ToAp1.applying(to: input)
        let achromatic = max(ap1.r, ap1.g, ap1.b)
        let distances = try normalizedDistances(ap1, achromatic: achromatic)
        let compressed = try RGB64(
            achromatic - compressDistance(distances.r, threshold: Self.thresholds.r, limit: Self.limits.r) * abs(achromatic),
            achromatic - compressDistance(distances.g, threshold: Self.thresholds.g, limit: Self.limits.g) * abs(achromatic),
            achromatic - compressDistance(distances.b, threshold: Self.thresholds.b, limit: Self.limits.b) * abs(achromatic)
        )
        return try Self.ap1ToAp0.applying(to: compressed)
    }

    /// Closed-form inverse from ACES 1.3 Equation 4b / the published CTL.
    /// Values at the inverse singularity have no finite preimage and are rejected.
    public func decompress(_ input: RGB64) throws -> RGB64 {
        guard input.r.isFinite, input.g.isFinite, input.b.isFinite else {
            throw ACESReferenceGamutCompressionError.nonFinite
        }
        let ap1 = try Self.ap0ToAp1.applying(to: input)
        let achromatic = max(ap1.r, ap1.g, ap1.b)
        let distances = try normalizedDistances(ap1, achromatic: achromatic)
        let decompressed = try RGB64(
            achromatic - decompressDistance(distances.r, threshold: Self.thresholds.r, limit: Self.limits.r) * abs(achromatic),
            achromatic - decompressDistance(distances.g, threshold: Self.thresholds.g, limit: Self.limits.g) * abs(achromatic),
            achromatic - decompressDistance(distances.b, threshold: Self.thresholds.b, limit: Self.limits.b) * abs(achromatic)
        )
        return try Self.ap1ToAp0.applying(to: decompressed)
    }

    private func normalizedDistances(_ rgb: RGB64, achromatic: Double) throws -> RGB64 {
        guard achromatic.isFinite else { throw ACESReferenceGamutCompressionError.nonFinite }
        if achromatic == 0 { return try RGB64(0, 0, 0) }
        return try RGB64(
            (achromatic - rgb.r) / abs(achromatic),
            (achromatic - rgb.g) / abs(achromatic),
            (achromatic - rgb.b) / abs(achromatic)
        )
    }

    private func compressDistance(_ distance: Double, threshold: Double, limit: Double) -> Double {
        guard distance >= threshold else { return distance }
        let p = Self.exponent
        let scale = compressionScale(threshold: threshold, limit: limit)
        let powered = pow((distance - threshold) / scale, p)
        return threshold + (distance - threshold) / pow(1 + powered, 1 / p)
    }

    private func decompressDistance(_ distance: Double, threshold: Double, limit: Double) throws -> Double {
        guard distance >= threshold else { return distance }
        let scale = compressionScale(threshold: threshold, limit: limit)
        guard distance <= threshold + scale else { return distance }
        let normalized = (distance - threshold) / scale
        let powered = pow(normalized, Self.exponent)
        guard powered < 1 else { throw ACESReferenceGamutCompressionError.nonInvertible }
        let result = threshold + scale * pow(powered / (1 - powered), 1 / Self.exponent)
        guard result.isFinite else { throw ACESReferenceGamutCompressionError.nonFinite }
        return result
    }

    private func compressionScale(threshold: Double, limit: Double) -> Double {
        let p = Self.exponent
        return (limit - threshold) / pow(
            pow((1 - threshold) / (limit - threshold), -p) - 1,
            1 / p
        )
    }
}
