import XCTest
import LUTAnalysis

final class MonotonicAnalysisContractsTests: XCTestCase {
    func testStrictIncreasingCurveReportsInvertibleStructure() throws {
        let report = try MonotonicCurve1DAnalyzer.analyze(values: [0, 0.25, 0.5, 1], domain: 0...1)
        XCTAssertEqual(report.direction, .increasing)
        XCTAssertTrue(report.isStrict)
        XCTAssertTrue(report.isInvertibleBySingleValue)
        XCTAssertEqual(report.flatSegmentIndices, [])
        XCTAssertEqual(report.reversalIndices, [])
        XCTAssertEqual(report.firstStep, 0.25, accuracy: 1e-15)
        XCTAssertEqual(report.lastStep, 0.5, accuracy: 1e-15)
        XCTAssertEqual(report.minimumAbsoluteStep, 0.25, accuracy: 1e-15)
        XCTAssertEqual(report.maximumAbsoluteStep, 0.5, accuracy: 1e-15)
    }

    func testDecreasingCurveAndFlatSegmentRemainExplicit() throws {
        let report = try MonotonicCurve1DAnalyzer.analyze(values: [1, 0.5, 0.5, 0], domain: -2...2)
        XCTAssertEqual(report.direction, .decreasing)
        XCTAssertFalse(report.isStrict)
        XCTAssertFalse(report.isInvertibleBySingleValue)
        XCTAssertEqual(report.flatSegmentIndices, [1])
        XCTAssertTrue(report.hasFlatSegments)
        let curve = try MonotonicCurve1D(values: [1, 0.5, 0.5, 0], domain: -2...2)
        XCTAssertFalse(curve.increasing)
        XCTAssertEqual(curve.analysis, report)
        XCTAssertEqual(curve.inverse(0.5).status, .nonUnique)
    }

    func testReversalsAreReportedWithoutEditingSamples() throws {
        let original = [0.0, 0.4, 0.2, 0.8, 0.8]
        let report = try MonotonicCurve1DAnalyzer.analyze(values: original, domain: 0...1)
        XCTAssertEqual(report.direction, .nonMonotonic)
        XCTAssertFalse(report.isInvertibleBySingleValue)
        XCTAssertEqual(report.reversalIndices, [2, 3])
        XCTAssertEqual(report.flatSegmentIndices, [3])
        XCTAssertEqual(original, [0, 0.4, 0.2, 0.8, 0.8])
        XCTAssertThrowsError(try MonotonicCurve1D(values: original, domain: 0...1)) {
            XCTAssertEqual($0 as? Curve1DError, .notMonotonic)
        }
    }

    func testConstantCurveIsMonotonicButNeverStrictlyInvertible() throws {
        let report = try MonotonicCurve1DAnalyzer.analyze(values: [0.5, 0.5, 0.5], domain: 0...1)
        XCTAssertEqual(report.direction, .constant)
        XCTAssertFalse(report.isStrict)
        XCTAssertEqual(report.flatSegmentIndices, [0, 1])
        let curve = try MonotonicCurve1D(values: [0.5, 0.5, 0.5], domain: 0...1)
        XCTAssertEqual(curve.inverse(0.5).status, .nonUnique)
    }

    func testStrictCurveUsesIndependentLinearReferenceOnNonUnitDomain() throws {
        let curve = try MonotonicCurve1D(values: [10, 20, 40], domain: -2...4)

        // The samples are uniformly spaced at -2, 1, and 4.  At x = 2.5,
        // the second segment's independent linear reference is 30.
        XCTAssertEqual(try curve.evaluate(2.5), 30, accuracy: 1e-15)

        let inverse = curve.inverse(30)
        XCTAssertEqual(inverse.status, .converged)
        XCTAssertEqual(inverse.value!, 2.5, accuracy: 2e-12)
        XCTAssertLessThanOrEqual(inverse.residual!, 2e-12)
    }
}
