import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class TetrahedralInverseContractsTests: XCTestCase {
    func testIdentityGridHasOneGloballyEnumeratedSolution() throws {
        let volume = try makeVolume(size: 4) { r, g, b in try RGB64(r, g, b) }
        let target = try RGB64(0.21, 0.56, 0.83)

        let report = try Tetrahedral3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.b, target.b, accuracy: 2e-12)
        XCTAssertEqual(report.unresolvedTetrahedronCount, 0)
        let replay = try volume.sample(report.solutions[0].input,
                                       interpolation: .tetrahedral, outside: .reject)
        XCTAssertEqual(replay.r, target.r, accuracy: 2e-12)
        XCTAssertEqual(replay.g, target.g, accuracy: 2e-12)
        XCTAssertEqual(replay.b, target.b, accuracy: 2e-12)
    }

    func testFoldedGridReportsBothBranchesInsteadOfChoosingOne() throws {
        let volume = try makeVolume(size: 3) { r, g, b in
            try RGB64(4 * r * (1 - r), g, b)
        }
        let report = try Tetrahedral3DInverse.analyze(try RGB64(0.5, 0.4, 0.7), in: volume)

        XCTAssertEqual(report.status, .multiple)
        XCTAssertEqual(report.solutions.count, 2)
        XCTAssertEqual(report.solutions[0].input.r, 0.25, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[1].input.r, 0.75, accuracy: 2e-12)
        XCTAssertTrue(report.solutions.allSatisfy { $0.residual <= 2e-12 })
    }

    func testOutsideTargetHasNoSolution() throws {
        let volume = try makeVolume(size: 3) { r, g, b in try RGB64(r, g, b) }
        let report = try Tetrahedral3DInverse.analyze(try RGB64(1.01, 0.5, 0.5), in: volume)

        XCTAssertEqual(report.status, .noSolution)
        XCTAssertTrue(report.solutions.isEmpty)
    }

    func testCollapsedMappingIsReportedAsUnresolvedNotUnique() throws {
        let volume = try makeVolume(size: 3) { _, g, b in try RGB64(0.5, g, b) }
        let report = try Tetrahedral3DInverse.analyze(try RGB64(0.5, 0.5, 0.5), in: volume)

        XCTAssertEqual(report.status, .unresolved)
        XCTAssertGreaterThan(report.unresolvedTetrahedronCount, 0)
    }

    func testImportedAnalysisRejectsImplicitShaperInversion() throws {
        let identity = try [RGB64(0, 0, 0), RGB64(1, 1, 1)]
        let shaper = try CubeShaper(size: 2, domain: .unit, samples: identity)
        let volumeSamples = try (0..<2).flatMap { b in
            try (0..<2).flatMap { g in
                try (0..<2).map { r in try RGB64(Double(r), Double(g), Double(b)) }
            }
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                              samples: volumeSamples,
                              shaper: shaper)

        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseTetrahedralColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5))) {
                XCTAssertEqual($0 as? Tetrahedral3DInverseError, .unsupportedLUT)
            }
    }

    func testInverseDiagnosticsRejectUnspecifiedNumericalModes() throws {
        let volume = try makeVolume(size: 2) { r, g, b in try RGB64(r, g, b) }
        XCTAssertThrowsError(try Tetrahedral3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, tolerance: .infinity)) {
                XCTAssertEqual($0 as? Tetrahedral3DInverseError, .invalidTolerance)
            }
        XCTAssertThrowsError(try Tetrahedral3DInverse.analyze(
            RGB64(0.5, 0.5, 0.5), in: volume, maxCondition: 0)) {
                XCTAssertEqual($0 as? Tetrahedral3DInverseError, .invalidConditionLimit)
            }
        let samples = try (0..<2).flatMap { b in
            try (0..<2).flatMap { g in
                try (0..<2).map { r in try RGB64(Double(r), Double(g), Double(b)) }
            }
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        XCTAssertThrowsError(try ImportedLUTAnalyzer.diagnoseTetrahedralColourInverse(
            lut: lut, output: RGB64(0.5, 0.5, 0.5), interpolation: .trilinear)) {
                XCTAssertEqual($0 as? ImportedLUTAnalysisError, .unsupportedInverseInterpolation)
            }
    }

    func testAffineGridMatchesIndependentMatrixInverse() throws {
        let matrix = try Matrix3x3(rowMajor: [1.1, 0.05, -0.03,
                                               0.02, 0.9, 0.04,
                                               -0.01, 0.06, 1.2])
        let offset = try RGB64(0.1, -0.04, 0.02)
        let transform = try KnownAffine3DTransform(matrix: matrix, offset: offset)
        let volume = try makeVolume(size: 5) { r, g, b in
            let linear = try matrix.applying(to: RGB64(r, g, b))
            return try RGB64(linear.r + offset.r, linear.g + offset.g, linear.b + offset.b)
        }
        let expected = try RGB64(0.3, 0.6, 0.7)
        let target = try transform.applying(to: expected)
        let report = try Tetrahedral3DInverse.analyze(target, in: volume)

        XCTAssertEqual(report.status, .unique)
        XCTAssertEqual(report.solutions.count, 1)
        XCTAssertEqual(report.solutions[0].input.r, expected.r, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.g, expected.g, accuracy: 2e-12)
        XCTAssertEqual(report.solutions[0].input.b, expected.b, accuracy: 2e-12)
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
