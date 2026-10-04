import LUTCore
import LUTFormats

public enum Trilinear3DInverseStatus: Equatable, Sendable {
    case unique
    case multiple
    case noSolution
    case unresolved
    case nonFinite
}

public struct Trilinear3DInverseSolution: Equatable, Sendable {
    public let input: RGB64
    public let residual: Double
}

public struct Trilinear3DInverseReport: Equatable, Sendable {
    public let status: Trilinear3DInverseStatus
    public let solutions: [Trilinear3DInverseSolution]
    public let unresolvedBoxCount: Int
}

public enum Trilinear3DInverseError: Error, Equatable, Sendable {
    case invalidTolerance
    case invalidMaxBoxes
    case unsupportedLUT
}

/// Conservative diagnostics for the multilinear interpolation used by a 3D LUT.
/// Roots are accepted only after replaying the production trilinear sampler;
/// singular boxes are reported as unresolved rather than assigned a fake root.
public enum Trilinear3DInverse {
    public static func analyze(_ output: RGB64, in volume: LUTVolume3D,
                               tolerance: Double = 2e-12,
                               maxBoxes: Int = 100_000) throws -> Trilinear3DInverseReport {
        guard tolerance.isFinite, tolerance >= 0 else { throw Trilinear3DInverseError.invalidTolerance }
        guard maxBoxes > 0 else { throw Trilinear3DInverseError.invalidMaxBoxes }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            return Trilinear3DInverseReport(status: .nonFinite, solutions: [], unresolvedBoxCount: 0)
        }
        let n = volume.size
        let boxCount = (n - 1) * (n - 1) * (n - 1)
        guard boxCount <= maxBoxes else { throw Trilinear3DInverseError.invalidMaxBoxes }
        var solutions: [Trilinear3DInverseSolution] = []
        var unresolved = 0
        for bz in 0..<(n - 1) {
            for by in 0..<(n - 1) {
                for bx in 0..<(n - 1) {
                    let corners = corners(of: volume, x: bx, y: by, z: bz)
                    guard contains(output, in: corners, tolerance: tolerance) else { continue }
                    let singular = singularAtCenter(corners: corners)
                    var acceptedInBox = false
                    for seed in seeds {
                        if let candidate = try solve(output: output, corners: corners,
                                                     seed: seed, tolerance: tolerance),
                           candidate.0.allSatisfy({ $0 >= -tolerance && $0 <= 1 + tolerance }) {
                            let p = input(candidate.0, cell: [bx, by, bz], volume: volume)
                            // The local polynomial is only a candidate generator. Acceptance must
                            // use the same sampler that production preview and export use.
                            guard let replay = try? volume.sample(p, interpolation: .trilinear,
                                                                  outside: .reject) else { continue }
                            let residual = replayResidual(replay, target: output)
                            let scale = max(1, abs(output.r), abs(output.g), abs(output.b))
                            guard residual <= tolerance * scale else { continue }
                            acceptedInBox = true
                            if !solutions.contains(where: { sameInput($0.input, p) }) {
                                solutions.append(Trilinear3DInverseSolution(input: p, residual: residual))
                            }
                        }
                    }
                    // A box whose output bounds contain the target but yielded no
                    // replay-validated root is not evidence of no solution: the
                    // finite Newton seed set may have missed a root. Keep the
                    // result conservative until a complete interval solver exists.
                    if singular || !acceptedInBox { unresolved += 1 }
                }
            }
        }
        solutions.sort {
            if $0.input.r != $1.input.r { return $0.input.r < $1.input.r }
            if $0.input.g != $1.input.g { return $0.input.g < $1.input.g }
            return $0.input.b < $1.input.b
        }
        let status: Trilinear3DInverseStatus
        if unresolved > 0 { status = .unresolved }
        else if solutions.count > 1 { status = .multiple }
        else if solutions.count == 1 { status = .unique }
        else { status = .noSolution }
        return Trilinear3DInverseReport(status: status, solutions: solutions,
                                        unresolvedBoxCount: unresolved)
    }

    public static func analyze(_ output: RGB64, in lut: CubeLUT,
                               tolerance: Double = 2e-12,
                               maxBoxes: Int = 100_000) throws -> Trilinear3DInverseReport {
        guard lut.dimension == .three, lut.shaper == nil else {
            throw Trilinear3DInverseError.unsupportedLUT
        }
        return try analyze(output, in: LUTVolume3D(size: lut.size, domain: lut.domain,
                                                   samples: lut.samples),
                           tolerance: tolerance, maxBoxes: maxBoxes)
    }

    private static let seeds: [[Double]] = [
        [0.5, 0.5, 0.5], [0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1],
        [1, 1, 0], [1, 0, 1], [0, 1, 1], [1, 1, 1],
        [0.25, 0.25, 0.25], [0.75, 0.25, 0.25], [0.25, 0.75, 0.25],
        [0.25, 0.25, 0.75], [0.75, 0.75, 0.75]
    ]

    private static func corners(of volume: LUTVolume3D, x: Int, y: Int, z: Int) -> [RGB64] {
        [0, 1, 2, 3, 4, 5, 6, 7].map { bit in
            let dx = bit & 1, dy = (bit >> 1) & 1, dz = (bit >> 2) & 1
            return volume.samples[(x + dx) + volume.size * ((y + dy) + volume.size * (z + dz))]
        }
    }

    private static func evaluate(_ q: [Double], _ c: [RGB64]) -> [Double] {
        let x = q[0], y = q[1], z = q[2]
        let wx = [1 - x, x], wy = [1 - y, y], wz = [1 - z, z]
        return (0..<3).map { channel in
            (0..<8).reduce(0) { sum, i in
                sum + c[i][channel] * wx[i & 1] * wy[(i >> 1) & 1] * wz[(i >> 2) & 1]
            }
        }
    }

    private static func jacobian(_ q: [Double], _ c: [RGB64]) -> Matrix3x3? {
        let h = 1e-6
        let a = q.map { max(0, $0 - h) }, b = q.map { min(1, $0 + h) }
        var rows = [Double]()
        for channel in 0..<3 {
            for axis in 0..<3 {
                let denominator = b[axis] - a[axis]
                if denominator == 0 { return nil }
                var low = q, high = q; low[axis] = a[axis]; high[axis] = b[axis]
                rows.append((evaluate(high, c)[channel] - evaluate(low, c)[channel]) / denominator)
            }
        }
        return try? Matrix3x3(rowMajor: rows)
    }

    private static func solve(output: RGB64, corners: [RGB64], seed: [Double], tolerance: Double)
        throws -> ([Double], Double)? {
        var q = seed
        for _ in 0..<32 {
            let value = evaluate(q, corners)
            let residuals = [value[0] - output.r, value[1] - output.g, value[2] - output.b]
            let scale = max(1, abs(output.r), abs(output.g), abs(output.b))
            let residual = residuals.map(abs).max()!
            if residual <= tolerance * scale { return (q, residual) }
            guard let matrix = jacobian(q, corners), let delta = try? matrix.solving(try RGB64(residuals[0], residuals[1], residuals[2])) else { return nil }
            q = zip(q, [delta.r, delta.g, delta.b]).map { min(1, max(0, $0 - $1)) }
        }
        return nil
    }

    private static func singularAtCenter(corners: [RGB64]) -> Bool {
        guard let matrix = jacobian([0.5, 0.5, 0.5], corners) else { return true }
        return (try? matrix.inverted()) == nil
    }

    private static func input(_ q: [Double], cell: [Int], volume: LUTVolume3D) -> RGB64 {
        let coordinate = (0..<3).map { (Double(cell[$0]) + q[$0]) / Double(volume.size - 1) }
        let minv = [volume.domain.min.r, volume.domain.min.g, volume.domain.min.b]
        let maxv = [volume.domain.max.r, volume.domain.max.g, volume.domain.max.b]
        return try! RGB64(minv[0] + coordinate[0] * (maxv[0] - minv[0]),
                          minv[1] + coordinate[1] * (maxv[1] - minv[1]),
                          minv[2] + coordinate[2] * (maxv[2] - minv[2]))
    }

    private static func contains(_ target: RGB64, in values: [RGB64], tolerance: Double) -> Bool {
        let scale = max(1, abs(target.r), abs(target.g), abs(target.b))
        let margin = tolerance * scale
        return (0..<3).allSatisfy { axis in
            let list = values.map { $0[axis] }
            return target[axis] >= list.min()! - margin && target[axis] <= list.max()! + margin
        }
    }

    private static func sameInput(_ a: RGB64, _ b: RGB64) -> Bool {
        let scale = max(1, abs(a.r), abs(a.g), abs(a.b), abs(b.r), abs(b.g), abs(b.b))
        let e = 64 * Double.ulpOfOne * scale
        return abs(a.r - b.r) <= e && abs(a.g - b.g) <= e && abs(a.b - b.b) <= e
    }

    private static func replayResidual(_ value: RGB64, target: RGB64) -> Double {
        max(abs(value.r - target.r), abs(value.g - target.g), abs(value.b - target.b))
    }
}
