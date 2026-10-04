import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class TrilinearInverseContractsTests: XCTestCase {
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
    }

    func testOutsideTargetHasNoSolution() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let report = try Trilinear3DInverse.analyze(try RGB64(1.01, 0.5, 0.5), in: volume)
        XCTAssertEqual(report.status, .noSolution)
        XCTAssertTrue(report.solutions.isEmpty)
        XCTAssertEqual(report.unresolvedBoxCount, 0)
    }

    func testCollapsedMappingIsUnresolved() throws {
        let volume = try makeVolume(size: 3) { _, g, b in try RGB64(0.5, g, b) }
        let report = try Trilinear3DInverse.analyze(try RGB64(0.5, 0.5, 0.5), in: volume)
        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedBoxCount, 0)
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
