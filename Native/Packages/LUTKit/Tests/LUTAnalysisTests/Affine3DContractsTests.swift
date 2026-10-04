import XCTest
import LUTCore
import LUTAnalysis

final class Affine3DContractsTests: XCTestCase {
    func testAffineModelAnalysisDistinguishesUniqueIllConditionedAndNonUnique() throws {
        let valid = try Matrix3x3(rowMajor: [1.2, 0.1, -0.05,
                                              0.02, 0.9, 0.04,
                                              -0.03, 0.08, 1.1])
        let validReport = Affine3DModelAnalysis.analyze(matrix: valid)
        XCTAssertEqual(validReport.status, .uniquelyInvertible)
        XCTAssertTrue(validReport.hasUniqueInverse)
        XCTAssertNotNil(validReport.conditionNumber)
        XCTAssertNotNil(validReport.identityResidual)

        let ill = try Matrix3x3(rowMajor: [1, 1, 1,
                                           1, 1 + 1e-10, 1,
                                           1, 1, 1 + 1e-10])
        let illReport = Affine3DModelAnalysis.analyze(matrix: ill, maxCondition: 1e8)
        XCTAssertEqual(illReport.status, .illConditioned)
        XCTAssertFalse(illReport.hasUniqueInverse)
        XCTAssertGreaterThan(illReport.conditionNumber ?? 0, 1e8)

        let singular = try Matrix3x3(rowMajor: [1, 2, 3,
                                                2, 4, 6,
                                                1, 1, 1])
        let singularReport = Affine3DModelAnalysis.analyze(matrix: singular)
        XCTAssertEqual(singularReport.status, .nonUnique)
        XCTAssertFalse(singularReport.hasUniqueInverse)
        XCTAssertNil(singularReport.conditionNumber)
    }

    func testAffineModelAnalysisRejectsInvalidConditionThreshold() throws {
        let report = Affine3DModelAnalysis.analyze(matrix: .identity, maxCondition: 0)
        XCTAssertEqual(report.status, .invalidTolerance)
        XCTAssertFalse(report.hasUniqueInverse)
    }

    func testKnownAffineTransformRoundTripsWithResidualGate() throws {
        let matrix = try Matrix3x3(rowMajor: [1.2, 0.1, -0.05,
                                               0.02, 0.9, 0.04,
                                               -0.03, 0.08, 1.1])
        let transform = try KnownAffine3DTransform(matrix: matrix, offset: try RGB64(0.1, -0.2, 0.05))
        let input = try RGB64(-0.3, 0.4, 1.2)
        let output = try transform.applying(to: input)
        let recovered = try transform.inverse(output, inputDomain: try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(2, 2, 2)))
        XCTAssertEqual(recovered.r, input.r, accuracy: 2e-14)
        XCTAssertEqual(recovered.g, input.g, accuracy: 2e-14)
        XCTAssertEqual(recovered.b, input.b, accuracy: 2e-14)
    }

    func testAffineAnalysisRejectsClippedOrOutOfDomainOutput() throws {
        let transform = try KnownAffine3DTransform(matrix: .identity, offset: try RGB64(0, 0, 0))
        let unit = LUTDomain.unit
        XCTAssertThrowsError(try transform.inverse(try RGB64(1.1, 0.5, 0.5),
                                                   inputDomain: unit, outputDomain: unit)) {
            XCTAssertEqual($0 as? Affine3DError, .outsideDomain)
        }
        XCTAssertThrowsError(try transform.inverse(try RGB64(1.1, 0.5, 0.5), inputDomain: unit)) {
            XCTAssertEqual($0 as? Affine3DError, .outsideDomain)
        }
    }

    func testAffineAnalysisRejectsSingularMatrixBeforeInversion() throws {
        let singular = try Matrix3x3(rowMajor: [1, 2, 3, 2, 4, 6, 1, 1, 1])
        XCTAssertThrowsError(try KnownAffine3DTransform(matrix: singular, offset: try RGB64(0, 0, 0))) {
            XCTAssertTrue(($0 as? MatrixError) == .singular || ($0 as? MatrixError) == .illConditioned)
        }
    }
}
