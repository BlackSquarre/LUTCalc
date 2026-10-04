import Foundation

public enum SolveStatus: String, Sendable {
    case converged
    case notBracketed
    case nonUnique
    case nonFinite
    case maxIterations
    case cancelled
    case evaluationFailed
}

public struct SolveTolerance: Sendable {
    public let xAbsolute: Double
    public let xRelative: Double
    public let fAbsolute: Double
    public let fRelative: Double
    public let maxIterations: Int

    var isValid: Bool {
        xAbsolute.isFinite && xAbsolute >= 0
            && xRelative.isFinite && xRelative >= 0
            && fAbsolute.isFinite && fAbsolute >= 0
            && fRelative.isFinite && fRelative >= 0
            && maxIterations >= 0
    }

    public init(
        xAbsolute: Double = 1e-12,
        xRelative: Double = 4 * Double.ulpOfOne,
        fAbsolute: Double = 1e-12,
        fRelative: Double = 2e-12,
        maxIterations: Int = 128
    ) {
        self.xAbsolute = xAbsolute
        self.xRelative = xRelative
        self.fAbsolute = fAbsolute
        self.fRelative = fRelative
        self.maxIterations = maxIterations
    }

    fileprivate func xLimit(at value: Double) -> Double { xAbsolute + xRelative * abs(value) }
    fileprivate func fLimit(for target: Double) -> Double { fAbsolute + fRelative * abs(target) }
}

public struct SolveResult: Sendable {
    public let status: SolveStatus
    public let value: Double?
    public let residual: Double?
    public let bracket: ClosedRange<Double>
    public let iterations: Int
    public let evaluations: Int
}

public enum RootSolver {
    public static func bisect(
        target: Double,
        bracket: ClosedRange<Double>,
        tolerance: SolveTolerance = .init(),
        function: (Double) throws -> Double
    ) -> SolveResult {
        solve(method: .bisection, target: target, bracket: bracket, tolerance: tolerance, function: function)
    }

    public static func brent(
        target: Double,
        bracket: ClosedRange<Double>,
        tolerance: SolveTolerance = .init(),
        function: (Double) throws -> Double
    ) -> SolveResult {
        solve(method: .brent, target: target, bracket: bracket, tolerance: tolerance, function: function)
    }

    private enum Method { case bisection, brent }

    private static func solve(
        method: Method, target: Double, bracket: ClosedRange<Double>,
        tolerance: SolveTolerance, function: (Double) throws -> Double
    ) -> SolveResult {
        var evaluations = 0
        func result(_ status: SolveStatus, _ value: Double? = nil, _ residual: Double? = nil,
                    _ interval: ClosedRange<Double> = bracket, _ iterations: Int = 0) -> SolveResult {
            SolveResult(status: status, value: value, residual: residual,
                        bracket: interval, iterations: iterations, evaluations: evaluations)
        }
        guard target.isFinite, bracket.lowerBound.isFinite, bracket.upperBound.isFinite,
              bracket.lowerBound < bracket.upperBound,
              tolerance.isValid else { return result(.nonFinite) }
        func evaluate(_ x: Double) throws -> Double {
            if Task.isCancelled { throw CancellationError() }
            let value = try function(x)
            evaluations += 1
            guard value.isFinite else { throw NonFiniteEvaluation() }
            let delta = value - target
            guard delta.isFinite else { throw NonFiniteEvaluation() }
            return delta
        }

        do {
            var a = bracket.lowerBound
            var b = bracket.upperBound
            var fa = try evaluate(a)
            var fb = try evaluate(b)
            if fa == 0 && fb == 0 { return result(.nonUnique, nil, 0) }
            if fa == 0 { return result(.converged, a, 0) }
            if fb == 0 { return result(.converged, b, 0) }
            guard (fa < 0 && fb > 0) || (fa > 0 && fb < 0) else {
                return result(.notBracketed, nil, min(abs(fa), abs(fb)))
            }
            if method == .bisection {
                for iteration in 1...max(1, tolerance.maxIterations) {
                    if iteration > tolerance.maxIterations { break }
                    let middle = a + (b - a) / 2
                    if middle == a || middle == b { break }
                    let fm = try evaluate(middle)
                    if fm == 0 { return result(.converged, middle, 0, a...b, iteration) }
                    if (fa < 0 && fm < 0) || (fa > 0 && fm > 0) {
                        a = middle; fa = fm
                    } else {
                        b = middle; fb = fm
                    }
                    let candidate = abs(fa) <= abs(fb) ? (a, fa) : (b, fb)
                    if b - a <= tolerance.xLimit(at: candidate.0),
                       abs(candidate.1) <= tolerance.fLimit(for: target) {
                        return result(.converged, candidate.0, abs(candidate.1), a...b, iteration)
                    }
                }
                return result(.maxIterations, nil, min(abs(fa), abs(fb)), a...b, tolerance.maxIterations)
            }

            var c = a
            var fc = fa
            var d = b - a
            var e = d
            for iteration in 1...max(1, tolerance.maxIterations) {
                if iteration > tolerance.maxIterations { break }
                if (fb > 0 && fc > 0) || (fb < 0 && fc < 0) {
                    c = a; fc = fa; d = b - a; e = d
                }
                if abs(fc) < abs(fb) {
                    let oldB = b, oldFB = fb
                    a = b; fa = fb
                    b = c; fb = fc
                    c = oldB; fc = oldFB
                }
                let halfWidth = (c - b) / 2
                let interval = min(b, c)...max(b, c)
                if fb == 0 { return result(.converged, b, 0, interval, iteration) }
                if abs(halfWidth) <= tolerance.xLimit(at: b),
                   abs(fb) <= tolerance.fLimit(for: target) {
                    return result(.converged, b, abs(fb), interval, iteration)
                }
                let stepLimit = 2 * Double.ulpOfOne * abs(b) + tolerance.xLimit(at: b) / 2
                if abs(e) >= stepLimit && abs(fa) > abs(fb) {
                    let s = fb / fa
                    var p: Double
                    var q: Double
                    if a == c {
                        p = 2 * halfWidth * s
                        q = 1 - s
                    } else {
                        let q0 = fa / fc
                        let r = fb / fc
                        p = s * (2 * halfWidth * q0 * (q0 - r) - (b - a) * (r - 1))
                        q = (q0 - 1) * (r - 1) * (s - 1)
                    }
                    if p > 0 { q = -q }
                    p = abs(p)
                    if q != 0 && 2 * p < min(3 * halfWidth * q - abs(stepLimit * q), abs(e * q)) {
                        e = d; d = p / q
                    } else {
                        d = halfWidth; e = d
                    }
                } else {
                    d = halfWidth; e = d
                }
                a = b; fa = fb
                b += abs(d) > stepLimit ? d : (halfWidth > 0 ? stepLimit : -stepLimit)
                fb = try evaluate(b)
            }
            return result(.maxIterations, nil, abs(fb), min(b, c)...max(b, c), tolerance.maxIterations)
        } catch is CancellationError {
            return result(.cancelled)
        } catch is NonFiniteEvaluation {
            return result(.nonFinite)
        } catch {
            return result(.evaluationFailed)
        }
    }

    private struct NonFiniteEvaluation: Error {}
}
