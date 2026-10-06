import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class TrilinearInverseContractsTests: XCTestCase {
    func testCancellationIsPropagatedBeforeScanningBoxes() async throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let task = Task { () throws -> Trilinear3DInverseReport in
            try Trilinear3DInverse.analyze(try RGB64(0.25, 0.5, 0.75), in: volume)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled trilinear inverse must not report a result")
        } catch is CancellationError {
            // Standard Swift cancellation is part of the inverse contract.
        }
    }

    func testIdentityGridHasOneSolution() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let target = try RGB64(0.23, 0.57, 0.81)
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.b, target.b, accuracy: 2e-12)
        XCTAssertEqual(report.unresolvedBoxCount, 0)
        XCTAssertEqual(report.enumeratedBoxCount, 8)
        XCTAssertEqual(report.candidateBoxCount, 1)
        XCTAssertTrue(report.isGloballyComplete)
        let replay = try volume.sample(report.solutions[0].input,
                                       interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(replay.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(replay.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(replay.b, target.b, accuracy: 2e-12)
    }

    func testFoldedGridReportsBothBranches() throws {
        let volume = try makeVolume(size: 3) { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        let report = try Trilinear3DInverse.analyze(try RGB64(0.5, 0.4, 0.7), in: volume)

        XCTAssertEqual(report.status, .multiple)
        XCTAssertEqual(report.solutions.count, 2)
        XCTAssertEqual(report.solutions[0].input.r, 0.25, accuracy: 2e-10)
        XCTAssertEqual(report.solutions[1].input.r, 0.75, accuracy: 2e-10)
        XCTAssertTrue(report.solutions.allSatisfy { $0.residual <= 2e-12 })
        XCTAssertTrue(report.isGloballyComplete)
    }

    func testOutsideTargetHasNoSolution() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let report = try Trilinear3DInverse.analyze(try RGB64(1.01, 0.5, 0.5), in: volume)
        XCTAssertEqual(report.status, .noSolution)
        XCTAssertTrue(report.solutions.isEmpty)
        XCTAssertEqual(report.unresolvedBoxCount, 0)
        XCTAssertEqual(report.enumeratedBoxCount, 8)
        XCTAssertEqual(report.candidateBoxCount, 0)
        XCTAssertTrue(report.isGloballyComplete)
    }


    func testCollapsedMappingIsUnresolved() throws {
        let volume = try makeVolume(size: 3) { _, g, b in try RGB64(0.5, g, b) }
        let report = try Trilinear3DInverse.analyze(try RGB64(0.5, 0.5, 0.5), in: volume)
        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedBoxCount, 0)
        XCTAssertFalse(report.isGloballyComplete)
    }

    func testRejectsInvalidParametersAndOtherInterpolation() throws {
        let volume = try makeVolume(size: 2) { r, g, b in try RGB64(r, g, b) }
        XCTAssertThrowsError(try Trilinear3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, tolerance: .infinity)) {
                XCTAssertEqual($0 as? Trilinear3DInverseError, .invalidTolerance)
            }
        XCTAssertThrowsError(try Trilinear3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, maxBoxes: 0)) {
                XCTAssertEqual($0 as? Trilinear3DInverseError, .invalidMaxBoxes)
            }
        let largerVolume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        XCTAssertThrowsError(try Trilinear3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: largerVolume, maxBoxes: 1)) {
                XCTAssertEqual($0 as? Trilinear3DInverseError, .invalidMaxBoxes)
            }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                              samples: volume.samples)
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseTrilinearColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5), interpolation: .tetrahedral)) {
                XCTAssertEqual($0 as? ImportedLUTAnalysisError, .unsupportedInverseInterpolation)
        }
    }

    func testAcceptedRootsAreValidatedByProductionSampler() throws {
        let volume = try makeVolume(size: 2) { r, g, b in
            try RGB64(r * r, g, b)
        }
        let target = try RGB64(0.25, 0.4, 0.6)
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        let root = try XCTUnwrap(report.solutions.first)
        let replay = try volume.sample(root.input, interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(root.residual, max(abs(replay.r - target.r),
                                          abs(replay.g - target.g),
                                          abs(replay.b - target.b)), accuracy: 1e-15)
        XCTAssertLessThanOrEqual(root.residual, 2e-12)
    }

    func testAnalyticJacobianHandlesStronglyScaledAffineCell() throws {
        let volume = try makeVolume(size: 2) { r, g, b in
            try RGB64(1_000_000 * r + 3 * g - 2 * b,
                      -4 * r + 500_000 * g + b,
                      2 * r - 5 * g + 700_000 * b)
        }
        let target = try RGB64(400_000 + 3 * 0.7 - 2 * 0.2,
                               -4 * 0.4 + 500_000 * 0.7 + 0.2,
                               2 * 0.4 - 5 * 0.7 + 700_000 * 0.2)
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        let input = try XCTUnwrap(report.solutions.first?.input)
        XCTAssertEqual(input.r, 0.4, accuracy: 2e-12)
        XCTAssertEqual(input.g, 0.7, accuracy: 2e-12)
        XCTAssertEqual(input.b, 0.2, accuracy: 2e-12)
    }

    func testBoundingBoxHitWithoutCertifiedRootIsUnresolved() throws {
        let volume = try makeVolume(size: 2) { r, g, b in
            try RGB64(r, g, 0.25 + 0.5 * r)
        }
        // The target is inside the per-channel corner bounds but outside the
        // actual output surface (blue is fixed to a different value).
        let report = try Trilinear3DInverse.analyze(try RGB64(0.4, 0.6, 0.5), in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertTrue(report.solutions.isEmpty)
        XCTAssertGreaterThan(report.unresolvedBoxCount, 0)
    }

    func testStrictAffineCellCertifiesNoSolutionOutsideParallelepiped() throws {
        let volume = try makeVolume(size: 2) { r, g, b in
            try RGB64(r + 0.5 * g,
                      g + 0.5 * b,
                      b + 0.5 * r)
        }
        // The target is inside each channel's corner range, but the affine
        // inverse has q.r > 1 and q.b < 0. A certified nonsingular affine
        // cell can therefore prove no solution without reporting unresolved.
        let report = try Trilinear3DInverse.analyze(try RGB64(1.4, 0.1, 0.1), in: volume)

        XCTAssertEqual(report.status, .noSolution)
        XCTAssertTrue(report.solutions.isEmpty)
        XCTAssertEqual(report.unresolvedBoxCount, 0)
    }

    func testNearAffineMixedTermCannotBeUsedToCertifyNoSolution() throws {
        let epsilon = 1e-13
        let volume = try makeVolume(size: 2) { r, g, b in
            try RGB64(r, g, b + epsilon * r * g)
        }
        let target = try RGB64(1, 1, 1 + epsilon)

        // The target is an exact boundary root. Treating the tiny mixed term
        // as zero would solve the affine approximation at z > 1 and falsely
        // certify no solution.
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input, try RGB64(1, 1, 1))
        XCTAssertGreaterThan(report.unresolvedBoxCount, 0)
    }

    func testBoundaryRootIsDeduplicatedAcrossAdjacentCells() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let target = try RGB64(0.5, 0.25, 0.75)
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input, target)
        XCTAssertEqual(report.unresolvedBoxCount, 0)
    }

    func testDomainMaximumBoundaryRootIsUnique() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let report = try Trilinear3DInverse.analyze(try RGB64(1, 1, 1), in: volume)
        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input, try RGB64(1, 1, 1))
        XCTAssertEqual(report.unresolvedBoxCount, 0)
    }

    func testNonUnitDomainMapsInverseCoordinatesBackToDomain() throws {
        let domain = try LUTDomain(min: RGB64(-2, 10, 100), max: RGB64(4, 22, 160))
        var samples: [RGB64] = []
        for b in 0..<3 {
            for g in 0..<3 {
                for r in 0..<3 {
                    let u = Double(r) / 2
                    let v = Double(g) / 2
                    let w = Double(b) / 2
                    samples.append(try RGB64(u, v, w))
                }
            }
        }
        let volume = try LUTVolume3D(size: 3, domain: domain, samples: samples)
        let target = try RGB64(0.2, 0.6, 0.8)
        let report = try Trilinear3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        let actual = report.solutions[0].input
        XCTAssertEqual(actual.r, -0.8, accuracy: 2e-12)
        XCTAssertEqual(actual.g, 17.2, accuracy: 2e-12)
        XCTAssertEqual(actual.b, 148, accuracy: 2e-12)
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
