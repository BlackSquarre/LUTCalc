public enum LUTInterpolation: String, Codable, Sendable {
    case trilinear
    case tetrahedral
    case tricubicLegacyV1
}

public enum LUTOutsidePolicy: String, Codable, Sendable {
    case reject
    case clampToDomain
    case legacyExtensionV1
}

public enum VolumeError: Error, Equatable, Sendable {
    case sampleCountMismatch
    case outsideDomain
    case unsupportedOutsidePolicy
}

public struct LUTVolume3D: Sendable {
    public let size: Int
    public let domain: LUTDomain
    public let samples: [RGB64]

    public init(size: Int, domain: LUTDomain, samples: [RGB64]) throws {
        let grid = try Grid3D(size: size, domain: domain)
        guard samples.count == grid.nodeCount else { throw VolumeError.sampleCountMismatch }
        self.size = size
        self.domain = domain
        self.samples = samples
    }

    public func sample(_ input: RGB64, interpolation: LUTInterpolation, outside: LUTOutsidePolicy) throws -> RGB64 {
        guard outside != .legacyExtensionV1 else { throw VolumeError.unsupportedOutsidePolicy }
        if interpolation == .tricubicLegacyV1 {
            return try LegacyTricubicVolume3D(size: size, domain: domain, samples: samples)
                .sample(input, outside: outside)
        }
        let values = [input.r, input.g, input.b]
        let minima = [domain.min.r, domain.min.g, domain.min.b]
        let maxima = [domain.max.r, domain.max.g, domain.max.b]
        if outside == .reject {
            for axis in 0..<3 where values[axis] < minima[axis] || values[axis] > maxima[axis] {
                throw VolumeError.outsideDomain
            }
        }
        var base = [Int](repeating: 0, count: 3)
        var fraction = [Double](repeating: 0, count: 3)
        for axis in 0..<3 {
            let clamped = min(max(values[axis], minima[axis]), maxima[axis])
            let u = (clamped - minima[axis]) / (maxima[axis] - minima[axis]) * Double(size - 1)
            let index = min(Int(u.rounded(.down)), size - 2)
            base[axis] = index
            fraction[axis] = u - Double(index)
        }
        switch interpolation {
        case .trilinear:
            var result = [Double](repeating: 0, count: 3)
            for b in 0...1 {
                for g in 0...1 {
                    for r in 0...1 {
                        let weight = (r == 1 ? fraction[0] : 1 - fraction[0])
                            * (g == 1 ? fraction[1] : 1 - fraction[1])
                            * (b == 1 ? fraction[2] : 1 - fraction[2])
                        let value = vertex(base, [r, g, b])
                        for channel in 0..<3 { result[channel] += weight * value[channel] }
                    }
                }
            }
            return try RGB64(result[0], result[1], result[2])
        case .tetrahedral:
            let order = [0, 1, 2].sorted { left, right in
                fraction[left] == fraction[right] ? left < right : fraction[left] > fraction[right]
            }
            let a = fraction[order[0]]
            let b = fraction[order[1]]
            let c = fraction[order[2]]
            var first = [0, 0, 0]
            first[order[0]] = 1
            var second = first
            second[order[1]] = 1
            let corners = [vertex(base, [0, 0, 0]), vertex(base, first), vertex(base, second), vertex(base, [1, 1, 1])]
            let weights = [1 - a, a - b, b - c, c]
            var result = [Double](repeating: 0, count: 3)
            for vertexIndex in 0..<4 {
                for channel in 0..<3 { result[channel] += weights[vertexIndex] * corners[vertexIndex][channel] }
            }
            return try RGB64(result[0], result[1], result[2])
        case .tricubicLegacyV1:
            return try LegacyTricubicVolume3D(size: size, domain: domain, samples: samples)
                .sample(input, outside: outside)
        }
    }

    private func vertex(_ base: [Int], _ offset: [Int]) -> RGB64 {
        let r = base[0] + offset[0]
        let g = base[1] + offset[1]
        let b = base[2] + offset[2]
        return samples[r + size * (g + size * b)]
    }
}
