import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis
import LUTSharedUI
@testable import LUTJobs

final class AffineInverseGenerationContractsTests: XCTestCase {
    private func plan() throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0))
    }

    private func affinePlan() throws -> KnownAffine3DInversePlan {
        let matrix = try Matrix3x3(rowMajor: [1.1, 0.1, 0.0,
                                               0.0, 0.9, 0.05,
                                               0.02, 0.0, 1.2])
        let transform = try KnownAffine3DTransform(matrix: matrix,
                                                    offset: RGB64(0.05, -0.02, 0.03))
        let inputDomain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(2, 2, 2))
        return KnownAffine3DInversePlan(transform: transform,
                                        inputDomain: inputDomain, outputDomain: .unit)
    }

    private func independentAffineInverse(_ output: RGB64) throws -> RGB64 {
        let a = 1.1, b = 0.1, c = 0.0
        let d = 0.0, e = 0.9, f = 0.05
        let g = 0.02, h = 0.0, i = 1.2
        let x = output.r - 0.05
        let y = output.g + 0.02
        let z = output.b - 0.03
        let determinant = a * (e * i - f * h)
            - b * (d * i - f * g)
            + c * (d * h - e * g)
        return try RGB64(
            ((e * i - f * h) * x + (c * h - b * i) * y + (b * f - c * e) * z) / determinant,
            ((f * g - d * i) * x + (a * i - c * g) * y + (c * d - a * f) * z) / determinant,
            ((d * h - e * g) * x + (b * g - a * h) * y + (a * e - b * d) * z) / determinant)
    }

    func testKnownAffineInverseIsAppliedBeforeTransformPlan() async throws {
        let inverse = try affinePlan()
        let request = try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
                                               blockNodes: 2, workerCount: 1,
                                               inputAffineInverse: inverse)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-affine-inverse-\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: output) }
        _ = try await NativeExportService().generate(request, to: output)
        let exported = try CubeParser.parse(Data(contentsOf: output))
        XCTAssertEqual(exported.dimension, .three)
        XCTAssertEqual(exported.size, 3)
        let samples = exported.samples
        let grid = try Grid3D(size: 3, domain: .unit)
        XCTAssertEqual(samples.count, grid.nodeCount)
        var maximumAbsoluteError = 0.0
        for index in 0..<grid.nodeCount {
            let expected = try independentAffineInverse(try grid.coordinate(at: index))
            maximumAbsoluteError = max(maximumAbsoluteError,
                                       max(abs(samples[index].r - expected.r),
                                           max(abs(samples[index].g - expected.g),
                                               abs(samples[index].b - expected.b))))
            XCTAssertEqual(samples[index].r, expected.r, accuracy: 2e-12)
            XCTAssertEqual(samples[index].g, expected.g, accuracy: 2e-12)
            XCTAssertEqual(samples[index].b, expected.b, accuracy: 2e-12)
        }
        print("显式仿射 3D 反求生成最大绝对误差：\(maximumAbsoluteError)")
    }

    func testAffineInverseCarriesIntoExposureBatchFingerprint() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-affine-batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let inverse = try affinePlan()
        let base = try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
                                            workerCount: 1, inputAffineInverse: inverse)
        let settings = try ExposureBatchSettings(minimumStops: 0, maximumStops: 1, subdivisions: 1)
        let request = try ExposureBatchRequest(base: base, settings: settings,
                                               directory: folder, basename: "affine", format: .cube)
        XCTAssertEqual(request.items.count, 2)
        XCTAssertTrue(request.items.allSatisfy { $0.request.inputAffineInverse?.contentFingerprint == inverse.contentFingerprint })
        let plain = try ExposureBatchRequest(
            base: LUTGenerationRequest(plan: plan(), size: 3, domain: .unit, workerCount: 1),
            settings: settings, directory: folder, basename: "affine", format: .cube)
        XCTAssertNotEqual(request.fingerprint, plain.fingerprint)
    }

    func testAffineInverseRejectsDomainMismatchAndConflicts() throws {
        let inverse = try affinePlan()
        XCTAssertThrowsError(try LUTGenerationRequest(plan: plan(), size: 2,
                                                       domain: try LUTDomain(min: RGB64(-1, -1, -1),
                                                                             max: RGB64(1, 1, 1)),
                                                       inputAffineInverse: inverse)) {
            XCTAssertEqual($0 as? JobFailure, .invalidInputInverseDomain)
        }
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                             RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let transferInverse = try ImportedLUTInversePlan(lut: transfer, analysisFile: nil,
                                                         interpolation: .tricubicLegacyV1)
        XCTAssertThrowsError(try LUTGenerationRequest(plan: plan(), size: 2, domain: .unit,
                                                       inputTransferInverse: transferInverse,
                                                       inputAffineInverse: inverse)) {
            XCTAssertEqual($0 as? JobFailure, .conflictingInputTransforms)
        }
    }

    func testSingularAffineModelIsRejectedBeforeGeneration() throws {
        let singular = try Matrix3x3(rowMajor: [1, 0, 0, 1, 0, 0, 0, 0, 1])
        XCTAssertThrowsError(try KnownAffine3DTransform(matrix: singular,
                                                        offset: RGB64(0, 0, 0))) {
            XCTAssertEqual($0 as? MatrixError, .singular)
        }
    }
}
