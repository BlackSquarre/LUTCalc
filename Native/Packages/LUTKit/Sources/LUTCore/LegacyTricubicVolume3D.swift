public enum LegacyTricubicError: Error, Equatable, Sendable {
    case insufficientStencil
    case resourceLimit
}

/// The in-domain cubic and ghost-node rules retained in js/lut.js.
/// Outside-domain behavior is explicit reject or clamp; the legacy derivative
/// extrapolation is intentionally a separate, unimplemented contract.
public struct LegacyTricubicVolume3D: Sendable {
    public let size: Int
    public let domain: LUTDomain
    private let extendedSize: Int
    private let mesh: [RGB64]

    public init(size: Int, domain: LUTDomain, samples: [RGB64]) throws {
        guard size >= 4 else { throw LegacyTricubicError.insufficientStencil }
        guard (0..<3).allSatisfy({ (domain.max[$0] - domain.min[$0]).isFinite }) else {
            throw NumericError.invalidDomain
        }
        let grid = try Grid3D(size: size, domain: domain)
        let (extendedSize, overflow) = size.addingReportingOverflow(2)
        guard !overflow else { throw NumericError.sizeOverflow }
        let extended = try Grid3D(size: extendedSize, domain: domain)
        guard extended.rgbDoubleBytes <= 64 * 1024 * 1024 else {
            throw LegacyTricubicError.resourceLimit
        }
        guard samples.count == grid.nodeCount else { throw VolumeError.sampleCountMismatch }
        let zero = try RGB64(0, 0, 0)
        var mesh = Array(repeating: zero, count: extended.nodeCount)
        for b in -1...size {
            for g in -1...size {
                for r in -1...size {
                    let position = [r, g, b]
                    let direction = position.map { $0 < 0 ? 1 : ($0 >= size ? -1 : 0) }
                    let value: RGB64
                    if direction == [0, 0, 0] {
                        value = samples[r + size * (g + size * b)]
                    } else {
                        // Faces extend along an axis, edges along a diagonal,
                        // and corners along the three-axis diagonal. All four
                        // source nodes are inside the original grid.
                        let points = (1...4).map { step -> RGB64 in
                            let q = (0..<3).map { position[$0] + step * direction[$0] }
                            return samples[q[0] + size * (q[1] + size * q[2])]
                        }
                        let channels = (0..<3).map { channel in
                            Self.ghost(far: points[3][channel], third: points[2][channel],
                                       second: points[1][channel], near: points[0][channel])
                        }
                        value = try RGB64(channels[0], channels[1], channels[2])
                    }
                    mesh[r + 1 + extendedSize * (g + 1 + extendedSize * (b + 1))] = value
                }
            }
        }
        self.size = size
        self.domain = domain
        self.extendedSize = extendedSize
        self.mesh = mesh
    }

    public func sample(_ input: RGB64, outside: LUTOutsidePolicy) throws -> RGB64 {
        guard outside != .legacyExtensionV1 else { throw VolumeError.unsupportedOutsidePolicy }
        var base: [Int] = []
        var weights: [[Double]] = []
        for axis in 0..<3 {
            let low = domain.min[axis], high = domain.max[axis]
            let value = input[axis]
            if outside == .reject && (value < low || value > high) {
                throw VolumeError.outsideDomain
            }
            let position = (min(max(value, low), high) - low) / (high - low) * Double(size - 1)
            let index = min(Int(position.rounded(.down)), size - 2)
            base.append(index)
            weights.append(Self.cubicWeights(position - Double(index)))
        }
        var output = [Double](repeating: 0, count: 3)
        for channel in 0..<3 {
            var blueSum = 0.0
            for b in 0..<4 {
                var greenSum = 0.0
                for g in 0..<4 {
                    var redSum = 0.0
                    for r in 0..<4 {
                        let index = base[0] + r + extendedSize *
                            (base[1] + g + extendedSize * (base[2] + b))
                        redSum += weights[0][r] * mesh[index][channel]
                    }
                    greenSum += redSum * weights[1][g]
                }
                blueSum += greenSum * weights[2][b]
            }
            output[channel] = blueSum
        }
        return try RGB64(output[0], output[1], output[2])
    }

    private static func cubicWeights(_ t: Double) -> [Double] {
        let square = t * t, cube = square * t
        return [-0.5 * cube + square - 0.5 * t,
                 1.5 * cube - 2.5 * square + 1,
                -1.5 * cube + 2 * square + 0.5 * t,
                 0.5 * cube - 0.5 * square]
    }

    private static func ghost(far: Double, third: Double, second: Double, near: Double) -> Double {
        if near == third { return second }
        let sign = near > third ? 1.0 : -1.0
        var value = -0.4 * far + 2.2 * third - 4.2 * second + 3.4 * near
        if (value - second) * sign <= 0 {
            value = third - 3 * second + 3 * near
            if (value - second) * sign <= 0 { value = second }
        }
        return value
    }
}
