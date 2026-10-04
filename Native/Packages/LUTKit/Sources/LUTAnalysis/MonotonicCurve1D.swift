import LUTCore

public enum Curve1DError: Error, Equatable, Sendable {
    case invalidSize
    case invalidDomain
    case nonFinite
    case notMonotonic
    case outsideDomain
}

public enum CurveMonotonicDirection: String, Equatable, Sendable {
    case increasing
    case decreasing
    case constant
    case nonMonotonic
}

/// Structural facts about a sampled 1D curve. The report never edits or
/// resamples the input; callers must decide whether a non-strict curve is
/// suitable for their analysis operation.
public struct MonotonicCurve1DAnalysis: Equatable, Sendable {
    public let sampleCount: Int
    public let direction: CurveMonotonicDirection
    public let isStrict: Bool
    /// Index of the left sample for each exactly flat adjacent pair.
    public let flatSegmentIndices: [Int]
    /// Index of the right sample at each sign reversal between non-zero steps.
    public let reversalIndices: [Int]
    public let firstStep: Double
    public let lastStep: Double
    public let minimumAbsoluteStep: Double
    public let maximumAbsoluteStep: Double

    public var hasFlatSegments: Bool { !flatSegmentIndices.isEmpty }
    public var isInvertibleBySingleValue: Bool { direction != .nonMonotonic && isStrict }
}

public enum MonotonicCurve1DAnalyzer {
    public static func analyze(values: [Double], domain: ClosedRange<Double>) throws -> MonotonicCurve1DAnalysis {
        guard values.count >= 2 else { throw Curve1DError.invalidSize }
        guard domain.lowerBound.isFinite, domain.upperBound.isFinite,
              domain.lowerBound < domain.upperBound else { throw Curve1DError.invalidDomain }
        guard values.allSatisfy(\.isFinite) else { throw Curve1DError.nonFinite }

        var flat: [Int] = []
        var reversals: [Int] = []
        var signs: [Int] = []
        signs.reserveCapacity(values.count - 1)
        var minimum = Double.infinity
        var maximum = 0.0
        for index in 1..<values.count {
            let step = values[index] - values[index - 1]
            guard step.isFinite else { throw Curve1DError.nonFinite }
            let magnitude = abs(step)
            minimum = min(minimum, magnitude)
            maximum = max(maximum, magnitude)
            if step == 0 {
                flat.append(index - 1)
                signs.append(0)
            } else {
                let sign = step > 0 ? 1 : -1
                if let previous = signs.last(where: { $0 != 0 }), previous != sign {
                    reversals.append(index)
                }
                signs.append(sign)
            }
        }
        let hasPositive = signs.contains(1)
        let hasNegative = signs.contains(-1)
        let direction: CurveMonotonicDirection
        if hasPositive && hasNegative {
            direction = .nonMonotonic
        } else if hasPositive {
            direction = .increasing
        } else if hasNegative {
            direction = .decreasing
        } else {
            direction = .constant
        }
        return MonotonicCurve1DAnalysis(
            sampleCount: values.count,
            direction: direction,
            isStrict: flat.isEmpty && direction != .constant,
            flatSegmentIndices: flat,
            reversalIndices: reversals,
            firstStep: values[1] - values[0],
            lastStep: values[values.count - 1] - values[values.count - 2],
            minimumAbsoluteStep: minimum,
            maximumAbsoluteStep: maximum
        )
    }
}

public struct MonotonicCurve1D: Sendable {
    public let values: [Double]
    public let domain: ClosedRange<Double>
    public let increasing: Bool
    public let analysis: MonotonicCurve1DAnalysis

    public init(values: [Double], domain: ClosedRange<Double>) throws {
        let report = try MonotonicCurve1DAnalyzer.analyze(values: values, domain: domain)
        guard report.direction != .nonMonotonic else { throw Curve1DError.notMonotonic }
        self.values = values
        self.domain = domain
        analysis = report
        increasing = report.direction != .decreasing
    }

    public func evaluate(_ x: Double) throws -> Double {
        guard x.isFinite else { throw Curve1DError.nonFinite }
        guard domain.contains(x) else { throw Curve1DError.outsideDomain }
        let position = (x - domain.lowerBound) / (domain.upperBound - domain.lowerBound) * Double(values.count - 1)
        let base = min(Int(position.rounded(.down)), values.count - 2)
        let fraction = position - Double(base)
        return values[base] * (1 - fraction) + values[base + 1] * fraction
    }

    public func inverse(_ target: Double, accelerated: Bool = true, tolerance: SolveTolerance = .init()) -> SolveResult {
        let full = domain
        guard target.isFinite else {
            return SolveResult(status: .nonFinite, value: nil, residual: nil, bracket: full, iterations: 0, evaluations: 0)
        }
        let exact = values.indices.filter { values[$0] == target }
        if let first = exact.first, let last = exact.last {
            let interval = coordinate(first)...coordinate(last)
            if first != last {
                return SolveResult(status: .nonUnique, value: nil, residual: 0, bracket: interval, iterations: 0, evaluations: 0)
            }
            return SolveResult(status: .converged, value: coordinate(first), residual: 0, bracket: interval, iterations: 0, evaluations: 0)
        }
        let low = min(values[0], values[values.count - 1])
        let high = max(values[0], values[values.count - 1])
        guard low <= target, target <= high else {
            return SolveResult(status: .notBracketed, value: nil, residual: min(abs(target - low), abs(target - high)), bracket: full, iterations: 0, evaluations: 0)
        }
        if accelerated {
            return RootSolver.brent(target: target, bracket: full, tolerance: tolerance) { try evaluate($0) }
        }
        return RootSolver.bisect(target: target, bracket: full, tolerance: tolerance) { try evaluate($0) }
    }

    private func coordinate(_ index: Int) -> Double {
        domain.lowerBound + Double(index) / Double(values.count - 1) * (domain.upperBound - domain.lowerBound)
    }
}
