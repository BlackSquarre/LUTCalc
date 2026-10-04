import LUTCore
import LUTFormats

public enum GrayAxisError: Error, Equatable, Sendable {
    case requiresThreeDimensionalLUT
}

public enum GrayAxisMethod: String, Equatable, Sendable {
    case normalizedDomainDiagonal
}

public struct GrayAxisSample: Equatable, Sendable {
    public let input: RGB64
    public let output: RGB64
}

public struct GrayAxisReport: Sendable {
    public let method: GrayAxisMethod
    public let interpolation: LUTInterpolation
    public let samples: [GrayAxisSample]
    public let midpointProbeCount: Int
    public let maximumMidpointResidual: Double
}

public enum GrayAxisAnalyzer {
    /// Samples the line joining the per-channel domain minima and maxima.
    /// Residual measures reconstruction along that line only, not the full 3D LUT.
    public static func extract(_ volume: LUTVolume3D,
                               interpolation: LUTInterpolation) throws -> GrayAxisReport {
        if interpolation == .tricubicLegacyV1 {
            let cubic = try LegacyTricubicVolume3D(size: volume.size, domain: volume.domain,
                                                  samples: volume.samples)
            return try extract(size: volume.size, domain: volume.domain, interpolation: interpolation) {
                try cubic.sample($0, outside: .reject)
            }
        }
        return try extract(size: volume.size, domain: volume.domain, interpolation: interpolation) {
            try volume.sample($0, interpolation: interpolation, outside: .reject)
        }
    }

    public static func extract(_ lut: CubeLUT,
                               interpolation: LUTInterpolation) throws -> GrayAxisReport {
        guard lut.dimension == .three else { throw GrayAxisError.requiresThreeDimensionalLUT }
        let sampler = try lut.preparedSampler(interpolation: interpolation)
        return try extract(size: lut.size, domain: lut.shaper?.domain ?? lut.domain,
                           interpolation: interpolation) {
            try sampler.sample($0, outside: .reject)
        }
    }

    private static func extract(size: Int, domain: LUTDomain, interpolation: LUTInterpolation,
                                sample: (RGB64) throws -> RGB64) throws -> GrayAxisReport {
        func input(at fraction: Double) throws -> RGB64 {
            let lower = domain.min
            let upper = domain.max
            return try RGB64(lower.r + fraction * (upper.r - lower.r),
                             lower.g + fraction * (upper.g - lower.g),
                             lower.b + fraction * (upper.b - lower.b))
        }

        var samples: [GrayAxisSample] = []
        samples.reserveCapacity(size)
        let stepCount = Double(size - 1)
        for index in 0..<size {
            let point = try input(at: Double(index) / stepCount)
            let output = try sample(point)
            samples.append(GrayAxisSample(input: point, output: output))
        }

        var maximumResidual = 0.0
        for index in 0..<(size - 1) {
            let midpoint = try input(at: (Double(index) + 0.5) / stepCount)
            let actual = try sample(midpoint)
            let left = samples[index].output
            let right = samples[index + 1].output
            for channel in 0..<3 {
                let reconstructed = left[channel] * 0.5 + right[channel] * 0.5
                maximumResidual = max(maximumResidual, abs(actual[channel] - reconstructed))
            }
        }
        return GrayAxisReport(method: .normalizedDomainDiagonal,
                              interpolation: interpolation, samples: samples,
                              midpointProbeCount: size - 1,
                              maximumMidpointResidual: maximumResidual)
    }
}
