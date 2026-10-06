import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class CombinedShaperColourInverseContractsTests: XCTestCase {
    func testCancellationIsPropagatedBeforeComposition() async throws {
        let lut = try makeLUT(size: 4, shaperSize: 4) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(r, g, b)
        }
        let task = Task { () throws -> CombinedShaperColourInverseReport in
            try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
                lut: lut, output: RGB64(0.25, 0.5, 0.75))
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancelled combined inverse must not report a result")
        } catch is CancellationError {
            // Cancellation is part of the inverse contract.
        }
    }

    func testIdentityShaperAndColourReplayOneSolution() throws {
        let lut = try makeLUT(size: 4,
                              shaperSize: 4) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(r, g, b)
        }
        let target = try RGB64(0.23, 0.57, 0.81)
        let report = try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: target)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 1)
        let solution = try XCTUnwrap(report.solutions.first)
        XCTAssertEqual(solution.input.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(solution.input.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(solution.input.b, target.b, accuracy: 2e-12)
        XCTAssertEqual(solution.residual, 0, accuracy: 2e-12)
        XCTAssertGreaterThan(report.unresolvedColourCellCount, 0)
        XCTAssertEqual(report.unresolvedShaperChannelCount, 0)
        XCTAssertFalse(report.isGloballyComplete)
    }

    func testFoldedShaperPreservesBothInputBranches() throws {
        let lut = try makeLUT(size: 4,
                              shaperSize: 5) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        let target = try RGB64(0.5, 0.4, 0.7)
        let report = try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: target)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 2)
        XCTAssertLessThan(report.solutions[0].input.r, 0.5)
        XCTAssertGreaterThan(report.solutions[1].input.r, 0.5)
        XCTAssertTrue(report.solutions.allSatisfy { $0.residual <= 2e-12 })
        XCTAssertFalse(report.isGloballyComplete)
    }

    func testMaxSolutionsRejectsWhenDistinctBranchesExceedLimit() throws {
        let lut = try makeLUT(size: 4, shaperSize: 5) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.4, 0.7), maxSolutions: 1)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .invalidInverseLimit)
        }
    }

    func testMaxSolutionsCountsDistinctRootsAfterBoundaryDeduplication() throws {
        let lut = try makeLUT(size: 3,
                              shaperSize: 3) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(r, g, b)
        }
        // The target lies on a colour cell boundary. Both adjacent cells can
        // generate the same production root, but duplicate candidates must
        // not consume the one-result limit.
        let report = try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.25, 0.75),
            colourInterpolation: .trilinear,
            shaperInterpolation: .trilinear,
            maxSolutions: 1)
        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.unresolvedColourCellCount, 0)
        XCTAssertEqual(report.unresolvedShaperChannelCount, 0)
        XCTAssertTrue(report.isGloballyComplete)
    }

    func testSingularColourRemainsUnresolvedAfterShaperComposition() throws {
        let lut = try makeLUT(size: 4,
                              shaperSize: 4) { _, g, b in
            try RGB64(0.5, g, b)
        } shaper: { r, g, b in
            try RGB64(r, g, b)
        }
        let report = try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedColourCellCount, 0)
    }

    func testRejectsInvalidParametersAndMissingShaper() throws {
        let plain = try makeLUT(size: 4, shaperSize: nil) { r, g, b in
            try RGB64(r, g, b)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: plain, output: RGB64(0.5, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .noShaperLUT)
        }

        let lut = try makeLUT(size: 4, shaperSize: 4) { r, g, b in
            try RGB64(r, g, b)
        } shaper: { r, g, b in
            try RGB64(r, g, b)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5), maxSolutions: 0)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .invalidInverseLimit)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5),
            colourInterpolation: .tetrahedral, maxCells: 1)) {
            XCTAssertEqual($0 as? Tetrahedral3DInverseError,
                           .invalidMaxTetrahedra)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5), tolerance: .infinity)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .invalidInverseLimit)
        }
    }

    private func makeLUT(
        size: Int,
        shaperSize: Int?,
        colour: (Double, Double, Double) throws -> RGB64,
        shaper: ((Double, Double, Double) throws -> RGB64)? = nil
    ) throws -> CubeLUT {
        var samples: [RGB64] = []
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    samples.append(try colour(Double(r) / Double(size - 1),
                                              Double(g) / Double(size - 1),
                                              Double(b) / Double(size - 1)))
                }
            }
        }
        var cubeShaper: CubeShaper?
        if let shaperSize, let shaper {
            var values: [RGB64] = []
            for index in 0..<shaperSize {
                let value = Double(index) / Double(shaperSize - 1)
                values.append(try shaper(value, value, value))
            }
            cubeShaper = try CubeShaper(size: shaperSize, domain: .unit, samples: values)
        } else {
            cubeShaper = nil
        }
        return try CubeLUT(dimension: .three, size: size, domain: .unit,
                           samples: samples, shaper: cubeShaper)
    }
}
