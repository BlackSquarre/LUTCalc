import Foundation
import LUTCore

/// Inverse support for the retained 1D LUTSpline cubic.  The forward curve
/// remains in LUTCore; this analysis layer only accepts a globally single
/// valued curve after checking every segment's derivative extrema.
public extension LegacyCubicCurve1D {
    /// Returns every finite root found in the complete cubic curve domain.
    /// Unlike `inverse`, this deliberately does not require global single
    /// valuedness, so callers can report all roots instead of collapsing a
    /// multi-valued curve into one error.
    func allInverseRoots(_ target: Double, tolerance: SolveTolerance = .init()) -> [SolveResult] {
        let full = lower...upper
        guard target.isFinite, tolerance.isValid else {
            return [SolveResult(status: .nonFinite, value: nil, residual: nil,
                                bracket: full, iterations: 0, evaluations: 0)]
        }

        var roots: [(value: Double, bracket: ClosedRange<Double>, residual: Double, evaluations: Int)] = []
        var nonUniqueBrackets: [ClosedRange<Double>] = []
        var failure: SolveStatus?

        func coordinate(_ segment: Int, _ t: Double) -> Double {
            lower + (Double(segment) + t) / Double(values.count - 1) * (upper - lower)
        }
        func value(_ segment: LegacyCubicSegment, _ t: Double) -> Double {
            ((segment.a * t + segment.b) * t + segment.c) * t + segment.d
        }
        func append(_ root: Double, _ bracket: ClosedRange<Double>, _ residual: Double,
                    _ evaluations: Int) {
            let duplicateLimit = tolerance.xAbsolute + tolerance.xRelative * abs(root)
            guard !roots.contains(where: { abs($0.value - root) <= duplicateLimit }) else { return }
            roots.append((root, bracket, residual, evaluations))
        }

        for segmentIndex in segments.indices {
            let segment = segments[segmentIndex]
            let cuts = ([0.0] + derivativeCriticalPoints(segment) + [1.0]).sorted()
            for intervalIndex in 0..<(cuts.count - 1) {
                let left = cuts[intervalIndex]
                let right = cuts[intervalIndex + 1]
                let leftValue = value(segment, left)
                let rightValue = value(segment, right)
                let leftDelta = leftValue - target
                let rightDelta = rightValue - target
                guard leftDelta.isFinite, rightDelta.isFinite else {
                    failure = .nonFinite
                    continue
                }
                let leftX = coordinate(segmentIndex, left)
                let rightX = coordinate(segmentIndex, right)
                if left < right, leftDelta == 0, rightDelta == 0 {
                    let middle = (left + right) * 0.5
                    if value(segment, middle) == target {
                        nonUniqueBrackets.append(leftX...rightX)
                        continue
                    }
                }
                if leftDelta == 0 {
                    append(leftX, leftX...leftX, 0, 0)
                }
                if rightDelta == 0 {
                    append(rightX, rightX...rightX, 0, 0)
                }
                guard leftDelta != 0, rightDelta != 0,
                      (leftDelta < 0 && rightDelta > 0) || (leftDelta > 0 && rightDelta < 0) else {
                    continue
                }
                let solved = RootSolver.brent(target: target, bracket: leftX...rightX,
                                              tolerance: tolerance) { x in
                    let p = (x - lower) / (upper - lower) * Double(values.count - 1)
                    let index = min(max(Int(p.rounded(.down)), 0), segments.count - 1)
                    return value(segments[index], p - Double(index))
                }
                switch solved.status {
                case .converged:
                    if let root = solved.value, let residual = solved.residual {
                        append(root, solved.bracket, residual, solved.evaluations)
                    }
                case .notBracketed:
                    break
                default:
                    failure = solved.status
                }
            }
        }
        roots.sort { $0.value < $1.value }
        let mergedBrackets = nonUniqueBrackets.sorted { $0.lowerBound < $1.lowerBound }
            .reduce(into: [ClosedRange<Double>]()) { merged, bracket in
                if let last = merged.last, last.upperBound == bracket.lowerBound {
                    merged[merged.count - 1] = last.lowerBound...bracket.upperBound
                } else {
                    merged.append(bracket)
                }
            }
        let isolatedRoots = roots.filter { root in
            !mergedBrackets.contains { $0.contains(root.value) }
        }
        var results = isolatedRoots.map { SolveResult(status: .converged, value: $0.value,
                                           residual: $0.residual, bracket: $0.bracket,
                                           iterations: 0, evaluations: $0.evaluations) }
        results.append(contentsOf: mergedBrackets.map {
            SolveResult(status: .nonUnique, value: nil, residual: 0,
                        bracket: $0, iterations: 0, evaluations: 0)
        })
        if !results.isEmpty {
            return results
        }
        if let failure {
            return [SolveResult(status: failure, value: nil, residual: nil,
                                bracket: full, iterations: 0, evaluations: 0)]
        }
        return [SolveResult(status: .notBracketed, value: nil, residual: nil,
                            bracket: full, iterations: 0, evaluations: 0)]
    }

    func inverse(_ target: Double, tolerance: SolveTolerance = .init()) -> SolveResult {
        let full = lower...upper
        guard target.isFinite else {
            return SolveResult(status: .nonFinite, value: nil, residual: nil,
                               bracket: full, iterations: 0, evaluations: 0)
        }
        guard tolerance.isValid else {
            return SolveResult(status: .nonFinite, value: nil, residual: nil,
                               bracket: full, iterations: 0, evaluations: 0)
        }
        guard isGloballySingleValued else {
            return SolveResult(status: .nonUnique, value: nil, residual: nil,
                               bracket: full, iterations: 0, evaluations: 0)
        }

        var roots: [Double] = []
        var rootBrackets: [ClosedRange<Double>] = []
        var evaluations = 0
        var smallestResidual = Double.infinity
        var failure: SolveStatus?

        func coordinate(_ segment: Int, _ t: Double) -> Double {
            let span = upper - lower
            return lower + (Double(segment) + t) / Double(values.count - 1) * span
        }
        func value(_ segment: LegacyCubicSegment, _ t: Double) -> Double {
            ((segment.a * t + segment.b) * t + segment.c) * t + segment.d
        }
        func recordResidual(_ residual: Double) {
            if residual < smallestResidual {
                smallestResidual = residual
            }
        }
        func appendRoot(_ x: Double, bracket: ClosedRange<Double>) {
            let duplicateLimit = tolerance.xAbsolute + tolerance.xRelative * abs(x)
            if roots.contains(where: { abs($0 - x) <= duplicateLimit }) { return }
            roots.append(x)
            rootBrackets.append(bracket)
        }

        for segmentIndex in segments.indices {
            let segment = segments[segmentIndex]
            let points = derivativeCriticalPoints(segment)
            var cuts = [0.0] + points + [1.0]
            cuts.sort()

            for intervalIndex in 0..<(cuts.count - 1) {
                let left = cuts[intervalIndex]
                let right = cuts[intervalIndex + 1]
                let leftValue = value(segment, left)
                let rightValue = value(segment, right)
                let leftDelta = leftValue - target
                let rightDelta = rightValue - target
                guard leftDelta.isFinite, rightDelta.isFinite else {
                    failure = .nonFinite
                    continue
                }
                recordResidual(abs(leftDelta))
                recordResidual(abs(rightDelta))

                if leftDelta == 0 {
                    appendRoot(coordinate(segmentIndex, left),
                               bracket: coordinate(segmentIndex, left)...coordinate(segmentIndex, left))
                }
                if rightDelta == 0 {
                    appendRoot(coordinate(segmentIndex, right),
                               bracket: coordinate(segmentIndex, right)...coordinate(segmentIndex, right))
                }
                if leftDelta == 0 || rightDelta == 0 { continue }

                if left == right {
                    if leftDelta == 0 { appendRoot(coordinate(segmentIndex, left),
                                                   bracket: coordinate(segmentIndex, left)...coordinate(segmentIndex, left)) }
                    continue
                }
                guard (leftDelta < 0 && rightDelta > 0) || (leftDelta > 0 && rightDelta < 0) else {
                    continue
                }

                let xLeft = coordinate(segmentIndex, left)
                let xRight = coordinate(segmentIndex, right)
                let solved = RootSolver.brent(target: target, bracket: xLeft...xRight,
                                              tolerance: tolerance) { x in
                    let p = (x - lower) / (upper - lower) * Double(values.count - 1)
                    let index = min(max(Int(p.rounded(.down)), 0), segments.count - 1)
                    let t = p - Double(index)
                    return value(segments[index], t)
                }
                evaluations += solved.evaluations
                switch solved.status {
                case .converged:
                    if let root = solved.value {
                        appendRoot(root, bracket: solved.bracket)
                    }
                case .nonUnique:
                    failure = .nonUnique
                case .notBracketed:
                    break
                default:
                    failure = solved.status
                }
            }
        }

        let foundNonUnique: Bool
        if case .some(.nonUnique) = failure { foundNonUnique = true } else { foundNonUnique = false }
        if roots.count > 1 || foundNonUnique {
            let interval = roots.isEmpty ? full : roots.min()!...roots.max()!
            return SolveResult(status: .nonUnique, value: nil, residual: 0,
                               bracket: interval, iterations: 0, evaluations: evaluations)
        }
        if let root = roots.first {
            let p = (root - lower) / (upper - lower) * Double(values.count - 1)
            let index = min(max(Int(p.rounded(.down)), 0), segments.count - 1)
            let t = p - Double(index)
            let residual = abs(value(segments[index], t) - target)
            return SolveResult(status: .converged, value: root,
                               residual: residual.isFinite ? residual : nil,
                               bracket: rootBrackets[0], iterations: 0,
                               evaluations: evaluations)
        }
        if let failure {
            return SolveResult(status: failure, value: nil,
                               residual: smallestResidual.isFinite ? smallestResidual : nil,
                               bracket: full, iterations: 0, evaluations: evaluations)
        }
        return SolveResult(status: .notBracketed, value: nil,
                           residual: smallestResidual.isFinite ? smallestResidual : nil,
                           bracket: full, iterations: 0, evaluations: evaluations)
    }

    var isGloballySingleValued: Bool {
        var hasPositiveSlope = false
        var hasNegativeSlope = false
        for segment in segments {
            var points = [0.0, 1.0]
            let quadratic = 3 * segment.a
            if quadratic != 0 {
                let vertex = -segment.b / quadratic
                if vertex > 0, vertex < 1, vertex.isFinite { points.append(vertex) }
            }
            for t in points {
                let slope = (3 * segment.a * t + 2 * segment.b) * t + segment.c
                guard slope.isFinite else { return false }
                hasPositiveSlope = hasPositiveSlope || slope > 0
                hasNegativeSlope = hasNegativeSlope || slope < 0
            }
            if segment.a == 0, segment.b == 0, segment.c == 0 { return false }
        }
        return hasPositiveSlope != hasNegativeSlope
    }
}

private func derivativeCriticalPoints(_ segment: LegacyCubicSegment) -> [Double] {
    let qa = 3 * segment.a
    let qb = 2 * segment.b
    let qc = segment.c
    var result: [Double] = []
    if qa == 0 {
        if qb != 0 {
            let root = -qc / qb
            if root > 0, root < 1, root.isFinite { result.append(root) }
        }
        return result
    }
    let discriminant = qb * qb - 4 * qa * qc
    guard discriminant >= 0, discriminant.isFinite else { return result }
    let root = sqrt(discriminant)
    let denominator = 2 * qa
    for candidate in [(-qb - root) / denominator, (-qb + root) / denominator]
        where candidate > 0 && candidate < 1 && candidate.isFinite {
        if !result.contains(candidate) { result.append(candidate) }
    }
    return result
}
