import LUTCore
import LUTFormats

public enum Tetrahedral3DInverseStatus: Equatable, Sendable {
    case unique
    case multiple
    case noSolution
    case unresolved
    case nonFinite
}

public struct Tetrahedral3DInverseSolution: Equatable, Sendable {
    public let input: RGB64
    public let residual: Double
}

/// Exhaustive inverse diagnostics for the existing tetrahedral interpolation
/// partition. A unique result is reported only when every tetrahedron whose
/// output bounds can contain the target has a numerically usable affine inverse.
public struct Tetrahedral3DInverseReport: Equatable, Sendable {
    public let status: Tetrahedral3DInverseStatus
    public let solutions: [Tetrahedral3DInverseSolution]
    public let unresolvedTetrahedronCount: Int
}

public enum Tetrahedral3DInverseError: Error, Equatable, Sendable {
    case invalidTolerance
    case invalidConditionLimit
    case unsupportedLUT
}

public enum Tetrahedral3DInverse {
    private static let axisOrders = [
        [0, 1, 2], [0, 2, 1], [1, 0, 2],
        [1, 2, 0], [2, 0, 1], [2, 1, 0],
    ]

    public static func analyze(_ output: RGB64, in volume: LUTVolume3D,
                               tolerance: Double = 2e-12,
                               maxCondition: Double = 1e8) throws -> Tetrahedral3DInverseReport {
        guard tolerance.isFinite, tolerance >= 0 else {
            throw Tetrahedral3DInverseError.invalidTolerance
        }
        guard maxCondition.isFinite, maxCondition > 0 else {
            throw Tetrahedral3DInverseError.invalidConditionLimit
        }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            return Tetrahedral3DInverseReport(status: .nonFinite, solutions: [],
                                               unresolvedTetrahedronCount: 0)
        }

        var solutions: [Tetrahedral3DInverseSolution] = []
        var unresolved = 0
        let n = volume.size
        for b in 0..<(n - 1) {
            for g in 0..<(n - 1) {
                for r in 0..<(n - 1) {
                    for order in axisOrders {
                        let offsets = tetrahedronOffsets(order)
                        let indices = offsets.map { offset in
                            (r + offset[0]) + n * ((g + offset[1]) + n * (b + offset[2]))
                        }
                        let outputs = indices.map { volume.samples[$0] }
                        guard contains(output, in: outputs, tolerance: tolerance) else { continue }

                        let edges = (1..<4).map { subtract(outputs[$0], outputs[0]) }
                        let matrix: Matrix3x3
                        let rightHandSide: RGB64
                        do {
                            matrix = try Matrix3x3(rowMajor: [
                                edges[0][0], edges[1][0], edges[2][0],
                                edges[0][1], edges[1][1], edges[2][1],
                                edges[0][2], edges[1][2], edges[2][2],
                            ])
                            rightHandSide = try rgb(subtract(output, outputs[0]))
                        } catch {
                            unresolved += 1
                            continue
                        }
                        let coordinates: RGB64
                        do {
                            _ = try matrix.inverted(maxCondition: maxCondition)
                            coordinates = try matrix.solving(rightHandSide)
                        } catch {
                            unresolved += 1
                            continue
                        }

                        let rawWeights = [1 - coordinates.r - coordinates.g - coordinates.b,
                                          coordinates.r, coordinates.g, coordinates.b]
                        guard rawWeights.allSatisfy({ $0 >= -tolerance && $0 <= 1 + tolerance }) else {
                            continue
                        }
                        let clippedWeights = rawWeights.map { min(max($0, 0), 1) }
                        let weightSum = clippedWeights.reduce(0, +)
                        guard weightSum.isFinite, weightSum > 0 else {
                            unresolved += 1
                            continue
                        }
                        let weights = clippedWeights.map { $0 / weightSum }
                        let inputValues = interpolateInput(offsets: offsets, weights: weights,
                                                            cell: [r, g, b], size: n,
                                                            domain: volume.domain)
                        guard let input = try? rgb(inputValues) else {
                            unresolved += 1
                            continue
                        }
                        let reconstructedValues = weighted(outputs, weights)
                        guard reconstructedValues.allSatisfy(\.isFinite) else {
                            unresolved += 1
                            continue
                        }
                        let residual = max(abs(reconstructedValues[0] - output.r),
                                           abs(reconstructedValues[1] - output.g),
                                           abs(reconstructedValues[2] - output.b))
                        let scale = max(1, abs(output.r), abs(output.g), abs(output.b))
                        guard residual.isFinite, residual <= tolerance * scale else { continue }
                        if let existing = solutions.firstIndex(where: {
                            sameInput($0.input, input)
                        }) {
                            if residual < solutions[existing].residual {
                                solutions[existing] = Tetrahedral3DInverseSolution(input: input,
                                                                                  residual: residual)
                            }
                        } else {
                            solutions.append(Tetrahedral3DInverseSolution(input: input,
                                                                          residual: residual))
                        }
                    }
                }
            }
        }
        solutions.sort {
            if $0.input.r != $1.input.r { return $0.input.r < $1.input.r }
            if $0.input.g != $1.input.g { return $0.input.g < $1.input.g }
            return $0.input.b < $1.input.b
        }
        let status: Tetrahedral3DInverseStatus
        if unresolved > 0 { status = .unresolved }
        else if solutions.count > 1 { status = .multiple }
        else if solutions.count == 1 { status = .unique }
        else { status = .noSolution }
        return Tetrahedral3DInverseReport(status: status, solutions: solutions,
                                           unresolvedTetrahedronCount: unresolved)
    }

    public static func analyze(_ output: RGB64, in lut: CubeLUT,
                               tolerance: Double = 2e-12,
                               maxCondition: Double = 1e8) throws -> Tetrahedral3DInverseReport {
        guard lut.dimension == .three, lut.shaper == nil else {
            throw Tetrahedral3DInverseError.unsupportedLUT
        }
        let volume = try LUTVolume3D(size: lut.size, domain: lut.domain, samples: lut.samples)
        return try analyze(output, in: volume, tolerance: tolerance,
                           maxCondition: maxCondition)
    }

    private static func tetrahedronOffsets(_ order: [Int]) -> [[Int]] {
        var first = [0, 0, 0]
        first[order[0]] = 1
        var second = first
        second[order[1]] = 1
        return [[0, 0, 0], first, second, [1, 1, 1]]
    }

    private static func subtract(_ left: RGB64, _ right: RGB64) -> [Double] {
        [left.r - right.r, left.g - right.g, left.b - right.b]
    }

    private static func rgb(_ values: [Double]) throws -> RGB64 {
        try RGB64(values[0], values[1], values[2])
    }

    private static func weighted(_ values: [RGB64], _ weights: [Double]) -> [Double] {
        [
            (0..<4).reduce(0.0) { $0 + values[$1].r * weights[$1] },
            (0..<4).reduce(0.0) { $0 + values[$1].g * weights[$1] },
            (0..<4).reduce(0.0) { $0 + values[$1].b * weights[$1] },
        ]
    }

    private static func contains(_ target: RGB64, in values: [RGB64], tolerance: Double) -> Bool {
        let scale = max(1, abs(target.r), abs(target.g), abs(target.b),
                        values.map { max(abs($0.r), abs($0.g), abs($0.b)) }.max() ?? 0)
        let margin = tolerance * scale
        return (0..<3).allSatisfy { channel in
            target[channel] >= (values.map { $0[channel] }.min() ?? 0) - margin
                && target[channel] <= (values.map { $0[channel] }.max() ?? 0) + margin
        }
    }

    private static func interpolateInput(offsets: [[Int]], weights: [Double],
                                         cell: [Int], size: Int,
                                         domain: LUTDomain) -> [Double] {
        var index = [Double](repeating: 0, count: 3)
        for vertex in 0..<4 {
            for axis in 0..<3 { index[axis] += weights[vertex] * Double(cell[axis] + offsets[vertex][axis]) }
        }
        let minima = [domain.min.r, domain.min.g, domain.min.b]
        let maxima = [domain.max.r, domain.max.g, domain.max.b]
        return [
            minima[0] + index[0] / Double(size - 1) * (maxima[0] - minima[0]),
            minima[1] + index[1] / Double(size - 1) * (maxima[1] - minima[1]),
            minima[2] + index[2] / Double(size - 1) * (maxima[2] - minima[2]),
        ]
    }

    private static func sameInput(_ left: RGB64, _ right: RGB64) -> Bool {
        let scale = max(1, abs(left.r), abs(left.g), abs(left.b),
                        abs(right.r), abs(right.g), abs(right.b))
        let limit = 64 * Double.ulpOfOne * scale
        return abs(left.r - right.r) <= limit
            && abs(left.g - right.g) <= limit
            && abs(left.b - right.b) <= limit
    }
}
