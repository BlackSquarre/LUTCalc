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
    public let enumeratedBoxCount: Int
    public let candidateBoxCount: Int
    public let isGloballyComplete: Bool
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
        try Task.checkCancellation()
        guard tolerance.isFinite, tolerance >= 0 else { throw Trilinear3DInverseError.invalidTolerance }
        guard maxBoxes > 0 else { throw Trilinear3DInverseError.invalidMaxBoxes }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            return Trilinear3DInverseReport(status: .nonFinite, solutions: [], unresolvedBoxCount: 0,
                                            enumeratedBoxCount: 0, candidateBoxCount: 0,
                                            isGloballyComplete: false)
        }
        let n = volume.size
        let boxesPerAxis = n - 1
        let (square, squareOverflow) = boxesPerAxis.multipliedReportingOverflow(by: boxesPerAxis)
        let (boxCount, cubeOverflow) = square.multipliedReportingOverflow(by: boxesPerAxis)
        guard !squareOverflow, !cubeOverflow, boxCount <= maxBoxes else {
            throw Trilinear3DInverseError.invalidMaxBoxes
        }
        var solutions: [Trilinear3DInverseSolution] = []
        var unresolved = 0
        var candidates = 0
        for bz in 0..<(n - 1) {
            try Task.checkCancellation()
            for by in 0..<(n - 1) {
                try Task.checkCancellation()
                for bx in 0..<(n - 1) {
                    try Task.checkCancellation()
                    let corners = corners(of: volume, x: bx, y: by, z: bz)
                    guard contains(output, in: corners, tolerance: tolerance) else { continue }
                    candidates += 1
                    if let affine = affineCellResult(output: output, corners: corners,
                                                     tolerance: tolerance) {
                        switch affine {
                        case .singular:
                            // A singular affine cell may contain a line or
                            // plane of roots. It is intentionally unresolved.
                            unresolved += 1
                        case .noSolution:
                            // For a nonsingular affine map, an inverse outside
                            // the unit cell is a proof that this cell has no root.
                            break
                        case .solution(let q):
                            let p = input(q, cell: [bx, by, bz], volume: volume)
                            guard let replay = try? volume.sample(p, interpolation: .trilinear,
                                                                  outside: .reject) else {
                                unresolved += 1
                                continue
                            }
                            let residual = replayResidual(replay, target: output)
                            let scale = max(1, abs(output.r), abs(output.g), abs(output.b))
                            guard residual.isFinite, residual <= tolerance * scale else {
                                unresolved += 1
                                continue
                            }
                            upsert(solution: Trilinear3DInverseSolution(input: p, residual: residual),
                                   into: &solutions)
                        }
                        continue
                    }
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
                            upsert(solution: Trilinear3DInverseSolution(input: p, residual: residual),
                                   into: &solutions)
                        }
                    }
                    // A non-affine trilinear cell has mixed terms. Newton
                    // roots are useful diagnostics, but finite seeds do not
                    // prove that every root was found. Keep all validated
                    // roots while marking the cell unresolved even when a
                    // candidate was accepted.
                    unresolved += 1
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
                                        unresolvedBoxCount: unresolved,
                                        enumeratedBoxCount: boxCount,
                                        candidateBoxCount: candidates,
                                        isGloballyComplete: unresolved == 0)
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
        guard q.count == 3 else { return nil }
        let x = q[0], y = q[1], z = q[2]
        let wx = [1 - x, x], wy = [1 - y, y], wz = [1 - z, z]
        var rows = [Double]()
        rows.reserveCapacity(9)
        for channel in 0..<3 {
            var dx = 0.0, dy = 0.0, dz = 0.0
            for i in 0..<8 {
                let sx = (i & 1) == 0 ? -1.0 : 1.0
                let sy = ((i >> 1) & 1) == 0 ? -1.0 : 1.0
                let sz = ((i >> 2) & 1) == 0 ? -1.0 : 1.0
                let value = c[i][channel]
                dx += value * sx * wy[(i >> 1) & 1] * wz[(i >> 2) & 1]
                dy += value * sy * wx[i & 1] * wz[(i >> 2) & 1]
                dz += value * sz * wx[i & 1] * wy[(i >> 1) & 1]
            }
            rows.append(contentsOf: [dx, dy, dz])
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

    private enum AffineCellResult {
        case singular
        case noSolution
        case solution([Double])
    }

    /// Returns nil when the trilinear cell has a genuine mixed term. When all
    /// mixed terms vanish within the requested numeric tolerance, the cell is
    /// certified as affine and can be classified exhaustively by one matrix
    /// solve. A singular affine map remains unresolved because its root set
    /// can be a line, plane, or the full cell.
    private static func affineCellResult(output: RGB64, corners c: [RGB64],
                                         tolerance: Double) -> AffineCellResult? {
        let mixed: [RGB64] = [
            try! RGB64(c[3].r - c[2].r - c[1].r + c[0].r,
                       c[3].g - c[2].g - c[1].g + c[0].g,
                       c[3].b - c[2].b - c[1].b + c[0].b),
            try! RGB64(c[5].r - c[4].r - c[1].r + c[0].r,
                       c[5].g - c[4].g - c[1].g + c[0].g,
                       c[5].b - c[4].b - c[1].b + c[0].b),
            try! RGB64(c[6].r - c[4].r - c[2].r + c[0].r,
                       c[6].g - c[4].g - c[2].g + c[0].g,
                       c[6].b - c[4].b - c[2].b + c[0].b),
            try! RGB64(c[7].r - c[6].r - c[5].r - c[3].r + c[4].r + c[2].r + c[1].r - c[0].r,
                       c[7].g - c[6].g - c[5].g - c[3].g + c[4].g + c[2].g + c[1].g - c[0].g,
                       c[7].b - c[6].b - c[5].b - c[3].b + c[4].b + c[2].b + c[1].b - c[0].b)
        ]
        // An approximate affine classification cannot certify no-solution:
        // even a sub-tolerance mixed term may create a boundary root outside
        // the affine approximation's unit parallelepiped. Only exact zero
        // mixed terms permit exhaustive affine classification; other cells
        // remain on the conservative Newton/unresolved path.
        guard mixed.allSatisfy({ $0.r == 0 && $0.g == 0 && $0.b == 0 }) else {
            return nil
        }
        let base = c[0]
        let x = subtract(c[1], base)
        let y = subtract(c[2], base)
        let z = subtract(c[4], base)
        let matrix: Matrix3x3
        let rhs: RGB64
        do {
            matrix = try Matrix3x3(rowMajor: [x.r, y.r, z.r,
                                               x.g, y.g, z.g,
                                               x.b, y.b, z.b])
            _ = try matrix.inverted()
            rhs = try RGB64(output.r - base.r, output.g - base.g, output.b - base.b)
            let q = try matrix.solving(rhs)
            let values = [q.r, q.g, q.b]
            guard values.allSatisfy(
                { $0.isFinite && $0 >= -tolerance && $0 <= 1 + tolerance }) else {
                return .noSolution
            }
            return .solution(values.map { min(1, max(0, $0)) })
        } catch {
            return .singular
        }
    }

    private static func subtract(_ a: RGB64, _ b: RGB64) -> RGB64 {
        try! RGB64(a.r - b.r, a.g - b.g, a.b - b.b)
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

    private static func upsert(solution: Trilinear3DInverseSolution,
                               into solutions: inout [Trilinear3DInverseSolution]) {
        if let index = solutions.firstIndex(where: { sameInput($0.input, solution.input) }) {
            if solution.residual < solutions[index].residual { solutions[index] = solution }
        } else {
            solutions.append(solution)
        }
    }

    private static func replayResidual(_ value: RGB64, target: RGB64) -> Double {
        max(abs(value.r - target.r), abs(value.g - target.g), abs(value.b - target.b))
    }
}
