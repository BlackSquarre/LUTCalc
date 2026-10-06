import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class TricubicInverseContractsTests: XCTestCase {
    func testCancellationIsPropagatedBeforeScanningCells() async throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let task = Task { () throws -> Tricubic3DInverseReport in
            try Tricubic3DInverse.analyze(try RGB64(0.25, 0.5, 0.75), in: volume)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled tricubic inverse must not report a result")
        } catch is CancellationError {
            // Standard Swift cancellation is part of the inverse contract.
        }
    }

    func testIdentityGridHasOneProductionReplayedSolution() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let target = try RGB64(0.23, 0.57, 0.81)

        let report = try Tricubic3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
        XCTAssertEqual(report.enumeratedCellCount, 27)
        XCTAssertGreaterThan(report.candidateCellCount, 0)
        XCTAssertFalse(report.isGloballyComplete)
        let solution = try XCTUnwrap(report.solutions.first)
        XCTAssertEqual(solution.input.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(solution.input.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(solution.input.b, target.b, accuracy: 2e-12)
        let replay = try volume.sample(solution.input,
                                       interpolation: .tricubicLegacyV1,
                                       outside: .reject)
        XCTAssertEqual(replay.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(replay.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(replay.b, target.b, accuracy: 2e-12)
        XCTAssertEqual(solution.residual, 0, accuracy: 2e-12)
    }

    func testFoldedCubicMappingReportsBothBranches() throws {
        let volume = try makeVolume(size: 5) { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        let report = try Tricubic3DInverse.analyze(try RGB64(0.5, 0.4, 0.7), in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 2)
        XCTAssertEqual(report.solutions[0].input.r, 0.1464466094067262, accuracy: 2e-10)
        XCTAssertEqual(report.solutions[1].input.r, 0.8535533905932737, accuracy: 2e-10)
        XCTAssertTrue(report.solutions.allSatisfy { $0.residual <= 2e-12 })
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
        XCTAssertFalse(report.isGloballyComplete)
    }

    func testExactCellBoundaryRootIsDeduplicatedAcrossAdjacentCells() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        // r = 1/3 is exactly the boundary between the first two interpolation
        // cells. Both cells may generate the same production root; diagnostics
        // must retain one root and must not classify the boundary as unresolved.
        let target = try RGB64(1.0 / 3.0, 0.37, 0.63)
        let report = try Tricubic3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.b, target.b, accuracy: 2e-12)
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
    }

    func testDomainMaximumBoundaryRootIsUnique() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let report = try Tricubic3DInverse.analyze(try RGB64(1, 1, 1), in: volume)
        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input, try RGB64(1, 1, 1))
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
    }

    func testTargetOutsideCertifiedCellRangesHasNoSolution() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let report = try Tricubic3DInverse.analyze(try RGB64(1.01, 0.5, 0.5), in: volume)

        XCTAssertEqual(report.status, .noSolution)
        XCTAssertTrue(report.solutions.isEmpty)
        XCTAssertEqual(report.unresolvedCellCount, 0)
        XCTAssertEqual(report.enumeratedCellCount, 27)
        XCTAssertEqual(report.candidateCellCount, 0)
        XCTAssertTrue(report.isGloballyComplete)
    }


    func testSingularCubicMappingIsUnresolved() throws {
        let volume = try makeVolume(size: 4) { _, g, b in try RGB64(0.5, g, b) }
        let report = try Tricubic3DInverse.analyze(try RGB64(0.5, 0.5, 0.5), in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
        XCTAssertFalse(report.isGloballyComplete)
    }

    func testIterationExhaustionInsideCertifiedBoundsIsUnresolved() throws {
        let volume = try makeVolume(size: 5) { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        // The target is in the certified bounds, but the requested tolerance
        // is below the finite Double replay floor.  Newton cannot prove a
        // root at that tolerance; this must remain unresolved rather than
        // being misreported as no solution.
        let report = try Tricubic3DInverse.analyze(
            try RGB64(0.5, 0.4, 0.7), in: volume, tolerance: 1e-30)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedCellCount, 0)
        XCTAssertTrue(report.solutions.isEmpty)
    }

    func testNonUnitDomainMapsBackToOriginalCoordinates() throws {
        let domain = try LUTDomain(min: RGB64(-2, 10, 100), max: RGB64(4, 22, 160))
        var samples: [RGB64] = []
        for b in 0..<4 {
            for g in 0..<4 {
                for r in 0..<4 {
                    samples.append(try RGB64(Double(r) / 3,
                                             Double(g) / 3,
                                             Double(b) / 3))
                }
            }
        }
        let volume = try LUTVolume3D(size: 4, domain: domain, samples: samples)
        let target = try RGB64(0.2, 0.6, 0.8)

        let report = try Tricubic3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unresolved)
        let input = try XCTUnwrap(report.solutions.first?.input)
        XCTAssertEqual(input.r, -0.8, accuracy: 2e-12)
        XCTAssertEqual(input.g, 17.2, accuracy: 2e-12)
        XCTAssertEqual(input.b, 148, accuracy: 2e-12)
    }

    func testAnalyticJacobianMatchesIndependentFiniteDifference() throws {
        let volume = try makeVolume(size: 5) { r, g, b in
            try RGB64(r * r + 0.2 * g - 0.1 * b,
                      0.3 * r + g * g + 0.1 * b,
                      0.15 * r - 0.25 * g + b * b)
        }
        let legacy = try LegacyTricubicVolume3D(size: volume.size,
                                                domain: volume.domain,
                                                samples: volume.samples)
        let point = try RGB64(0.37, 0.42, 0.61)
        let evaluation = try legacy.sampleWithJacobian(point, outside: .reject)
        let h = 1e-6
        for axis in 0..<3 {
            var plus = [point.r, point.g, point.b]
            var minus = plus
            plus[axis] += h
            minus[axis] -= h
            let plusValue = try legacy.sample(try RGB64(plus[0], plus[1], plus[2]),
                                              outside: .reject)
            let minusValue = try legacy.sample(try RGB64(minus[0], minus[1], minus[2]),
                                               outside: .reject)
            for channel in 0..<3 {
                let finiteDifference = (plusValue[channel] - minusValue[channel]) / (2 * h)
                XCTAssertEqual(evaluation.jacobian[channel, axis], finiteDifference,
                               accuracy: 2e-7)
            }
        }
    }

    func testBernsteinCellBoundsContainProductionOvershoot() throws {
        let volume = try makeVolume(size: 4) { r, g, b in
            try RGB64(1.3 * r * r - 0.4 * g + 0.2 * b,
                      0.1 * r + 1.1 * g * g - 0.3 * b,
                      -0.2 * r + 0.25 * g + 0.9 * b * b)
        }
        let legacy = try LegacyTricubicVolume3D(size: volume.size,
                                                domain: volume.domain,
                                                samples: volume.samples)
        let cell = [1, 0, 2]
        let bounds = try legacy.cellOutputBounds(cell)
        for q in [[0.03, 0.17, 0.91], [0.44, 0.52, 0.28], [0.96, 0.81, 0.06]] {
            let point = try RGB64((Double(cell[0]) + q[0]) / 3,
                                  (Double(cell[1]) + q[1]) / 3,
                                  (Double(cell[2]) + q[2]) / 3)
            let output = try legacy.sample(point, outside: .reject)
            for channel in 0..<3 {
                XCTAssertGreaterThanOrEqual(output[channel], bounds[channel].lowerBound - 1e-12)
                XCTAssertLessThanOrEqual(output[channel], bounds[channel].upperBound + 1e-12)
            }
        }
    }

    func testRejectsInvalidParametersAndShaperLUT() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let plainLUT = try CubeLUT(dimension: .three, size: 4, domain: .unit,
                                   samples: volume.samples)
        let plainReport = try ImportedLUTAnalyzer.diagnoseTricubicColourInverse(
            lut: plainLUT, output: RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(plainReport.status, .unresolved)
        XCTAssertThrowsError(try Tricubic3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, tolerance: .infinity)) {
                XCTAssertEqual($0 as? Tricubic3DInverseError, .invalidTolerance)
            }
        XCTAssertThrowsError(try Tricubic3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, maxCells: 0)) {
                XCTAssertEqual($0 as? Tricubic3DInverseError, .invalidMaxCells)
            }

        let identity = try [RGB64(0, 0, 0), RGB64(1, 1, 1)]
        let shaper = try CubeShaper(size: 2, domain: .unit, samples: identity)
        let lut = try CubeLUT(dimension: .three, size: 4, domain: .unit,
                              samples: volume.samples, shaper: shaper)
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseTricubicColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5))) {
                XCTAssertEqual($0 as? Tricubic3DInverseError, .unsupportedLUT)
            }
    }

    private func makeVolume(size: Int,
                            transform: (Double, Double, Double) throws -> RGB64) throws -> LUTVolume3D {
        var samples: [RGB64] = []
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    samples.append(try transform(Double(r) / Double(size - 1),
                                                  Double(g) / Double(size - 1),
                                                  Double(b) / Double(size - 1)))
                }
            }
        }
        return try LUTVolume3D(size: size, domain: .unit, samples: samples)
    }
}
