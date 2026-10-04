public enum LegacyCubicCurveError: Error, Equatable, Sendable {
    case insufficientStencil
    case resourceLimit
}

/// Cubic Hermite coefficients for one normalized segment, evaluated as
/// `((a * t + b) * t + c) * t + d`, with `0 <= t <= 1`.
public struct LegacyCubicSegment: Equatable, Sendable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double

    public init(a: Double, b: Double, c: Double, d: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }
}

/// Slopes use the sample-index coordinate, as in the retained LUTSpline.
public struct LegacyCubicEndpointSlopes: Equatable, Sendable {
    public struct Endpoint: Equatable, Sendable {
        public let raw: Double
        public let applied: Double
        public var modified: Bool { raw != applied }
        public var delta: Double { applied - raw }
    }
    public let direction: Double
    public let lower: Endpoint
    public let upper: Endpoint
}

/// Forward-only LUTSpline compatibility. Does not imply monotonicity or inversion.
public struct LegacyCubicCurve1D: Sendable {
    // Budget includes the original values, four coefficients and transient slopes.
    public static let maximumSampleCount = 64 * 1024 * 1024 / (6 * MemoryLayout<Double>.stride)
    public let values: [Double]
    public let lower: Double
    public let upper: Double
    public let endpointSlopes: LegacyCubicEndpointSlopes
    public let segments: [LegacyCubicSegment]

    public init(values: [Double], lower: Double, upper: Double) throws {
        guard values.count >= 3 else { throw LegacyCubicCurveError.insufficientStencil }
        guard values.count <= Self.maximumSampleCount else { throw LegacyCubicCurveError.resourceLimit }
        guard lower.isFinite, upper.isFinite, lower < upper, (upper-lower).isFinite else {
            throw NumericError.invalidDomain
        }
        guard values.allSatisfy(\.isFinite) else { throw NumericError.nonFinite }
        let n = values.count
        let direction = values[n-1] >= values[0] ? 1.0 : -1.0
        let rawLower = -0.5 * values[2] + 2 * values[1] - 1.5 * values[0]
        let rawUpper = 0.5 * values[n-3] - 2 * values[n-2] + 1.5 * values[n-1]
        guard rawLower.isFinite, rawUpper.isFinite else { throw NumericError.nonFinite }
        let fallback = 0.0075 * direction / Double(n-1)
        let left = rawLower * direction <= 0 ? fallback : rawLower
        let right = rawUpper * direction <= 0 ? fallback : rawUpper
        var slopes = [Double](repeating: 0, count: n)
        slopes[0] = left; slopes[n-1] = right
        for j in 1..<(n-1) { slopes[j] = (values[j+1]-values[j-1])/2 }
        var coefficients: [LegacyCubicSegment] = []
        coefficients.reserveCapacity(n-1)
        for j in 0..<(n-1) {
            let a = 2 * values[j] + slopes[j] - 2 * values[j+1] + slopes[j+1]
            let b = -3 * values[j] - 2 * slopes[j] + 3 * values[j+1] - slopes[j+1]
            guard a.isFinite, b.isFinite, slopes[j].isFinite else { throw NumericError.nonFinite }
            coefficients.append(LegacyCubicSegment(a: a, b: b, c: slopes[j], d: values[j]))
        }
        self.values = values; self.lower = lower; self.upper = upper
        self.endpointSlopes = LegacyCubicEndpointSlopes(direction: direction,
            lower: .init(raw: rawLower, applied: left), upper: .init(raw: rawUpper, applied: right))
        self.segments = coefficients
    }

    public func sample(_ input: Double, outside: LUTOutsidePolicy) throws -> Double {
        guard input.isFinite else { throw NumericError.nonFinite }
        if outside == .reject && (input < lower || input > upper) { throw VolumeError.outsideDomain }
        let value = outside == .clampToDomain ? min(max(input, lower), upper) : input
        let last = Double(values.count-1)
        let p = (value-lower)/(upper-lower) * last
        guard p.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if p <= 0 { result = p * endpointSlopes.lower.applied + values[0] }
        else if p >= last { result = (p-last) * endpointSlopes.upper.applied + values[values.count-1] }
        else {
            let index = Int(p.rounded(.down))
            let t = p-Double(index)
            let s = segments[index]
            result = ((s.a*t+s.b)*t+s.c)*t+s.d
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
