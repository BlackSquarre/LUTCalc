import XCTest
import LUTAnalysis
import LUTCore

final class RootContractsTests: XCTestCase {
    func testEndpointAndNoRoot() throws {
        let endpoint = RootSolver.bisect(target: 0, bracket: 0...2) { $0 * $0 }
        XCTAssertEqual(endpoint.status, .converged)
        XCTAssertEqual(endpoint.value, 0)
        let noRoot = RootSolver.bisect(target: 0, bracket: -1...1) { _ in 1 }
        XCTAssertEqual(noRoot.status, .notBracketed)
        XCTAssertNil(noRoot.value)
    }

    func testFlatIntervalAndNonFinite() throws {
        let flat = RootSolver.bisect(target: 1, bracket: 0...1) { _ in 1 }
        XCTAssertEqual(flat.status, .nonUnique)
        let nonFinite = RootSolver.bisect(target: 0, bracket: 0...1) { _ in .nan }
        XCTAssertEqual(nonFinite.status, .nonFinite)
    }

    func testInfiniteToleranceIsRejectedWithoutEvaluatingFunction() throws {
        let tolerance = SolveTolerance(xAbsolute: .infinity)
        var evaluations = 0
        let result = RootSolver.brent(target: 0.5, bracket: 0...1,
                                      tolerance: tolerance) { x in
            evaluations += 1
            return x
        }
        XCTAssertEqual(result.status, .nonFinite)
        XCTAssertNil(result.value)
        XCTAssertEqual(evaluations, 0)

        let curve = try LegacyCubicCurve1D(values: [0, 0.5, 1], lower: 0, upper: 1)
        let roots = curve.allInverseRoots(0.5, tolerance: tolerance)
        XCTAssertEqual(roots.map(\.status), [.nonFinite])
        XCTAssertNil(roots[0].value)
    }

    func testBrentAndBisectionAgree() throws {
        let baseline = RootSolver.bisect(target: 2, bracket: 0...2) { $0 * $0 }
        let brent = RootSolver.brent(target: 2, bracket: 0...2) { $0 * $0 }
        XCTAssertEqual(baseline.status, .converged)
        XCTAssertEqual(brent.status, .converged)
        XCTAssertEqual(brent.value!, baseline.value!, accuracy: 1e-12)
    }

    func testImportedMonotonic1DFlatSegmentIsExplicit() throws {
        let original = [0.0, 0.5, 0.5, 1.0]
        let curve = try MonotonicCurve1D(values: original, domain: 0...1)
        let flat = curve.inverse(0.5)
        XCTAssertEqual(flat.status, .nonUnique)
        XCTAssertEqual(flat.bracket.lowerBound, 1.0 / 3.0, accuracy: 1e-12)
        let unique = curve.inverse(0.75)
        XCTAssertEqual(unique.status, .converged)
        XCTAssertEqual(unique.value!, 5.0 / 6.0, accuracy: 1e-12)
        XCTAssertEqual(original, [0, 0.5, 0.5, 1])
    }

    func testLegacyCubicInverseRecoversMonotonicCurveAndRejectsGloballyNonMonotonicCurve() throws {
        let curve = try LegacyCubicCurve1D(values: [0, 0.25, 0.75, 1], lower: -1, upper: 2)
        let input = 0.37
        // Independent Decimal Hermite evaluation at segment 1, t = 0.37.
        let target = 0.42742425
        let recovered = curve.inverse(target)
        XCTAssertEqual(recovered.status, .converged)
        XCTAssertEqual(recovered.value!, input, accuracy: 2e-12)
        XCTAssertLessThanOrEqual(recovered.residual!, 2e-14)

        let hump = try LegacyCubicCurve1D(values: [0, 1, 1, 0], lower: 0, upper: 1)
        let multiple = hump.inverse(1.125)
        XCTAssertEqual(multiple.status, .nonUnique)
        XCTAssertNil(multiple.value)
    }

    func testLegacyCubicInverseTreatsConstantSegmentAsNonUnique() throws {
        let flat = try LegacyCubicCurve1D(values: [0.375, 0.375, 0.375], lower: 0, upper: 1)
        XCTAssertEqual(flat.inverse(0.375).status, .nonUnique)
        XCTAssertEqual(flat.inverse(.nan).status, .nonFinite)
    }

    func testLegacyCubicKeepsFiniteCriticalPointWhenDiscriminantOverflows() throws {
        let curve = try LegacyCubicCurve1D(
            values: [8.984900966844184e258, 1.3457406847046075e265,
                     -3.225797001415437e282],
            lower: 0,
            upper: 1
        )
        // The first segment's derivative has a finite t = 2/3 critical point,
        // although the unscaled quadratic discriminant overflows to infinity.
        let target = try curve.sample(1.0 / 3.0, outside: .reject)
        let roots = curve.allInverseRoots(target)
        XCTAssertTrue(roots.contains { result in
            guard result.status == .converged, let value = result.value else { return false }
            return abs(value - 1.0 / 3.0) <= 1e-12
        }, "finite tangent root was lost when the raw discriminant overflowed: \(roots)")
    }
}
