import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis
@testable import LUTJobs

final class LegacyCubicInverseGenerationContractsTests: XCTestCase {
    private func identityPlan() throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0))
    }

    func testStrictCubicInverseIsAppliedBeforeTransformPlan() async throws {
        let curve = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                          RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let inverse = try ImportedLUTInversePlan(lut: curve, analysisFile: nil,
                                                 interpolation: .tricubicLegacyV1)
        let request = try LUTGenerationRequest(plan: identityPlan(), size: 3, domain: .unit,
                                               blockNodes: 2, workerCount: 1,
                                               inputTransferInverse: inverse)
        let sink = InMemoryCubeSink()
        _ = try await GenerationCoordinator().generate(request, sink: sink)
        let samples = await sink.samples
        XCTAssertEqual(samples.count, 27)
        XCTAssertEqual(samples[13].r, 0.5, accuracy: 2e-12)
        XCTAssertEqual(samples[13].g, 0.5, accuracy: 2e-12)
        XCTAssertEqual(samples[13].b, 0.5, accuracy: 2e-12)
    }

    func testInversePlanRejectsNonUniqueCubicCurvesBeforeGeneration() throws {
        let hump = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                               samples: [RGB64(0, 0, 0), RGB64(1, 1, 1),
                                         RGB64(1, 1, 1), RGB64(0, 0, 0)])
        XCTAssertThrowsError(try ImportedLUTInversePlan(lut: hump, analysisFile: nil,
                                                         interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .nonUniqueTransfer)
        }
    }

    func testInputShaperAndInverseCannotBeCombinedImplicitly() throws {
        let curve = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                                samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 1, 1)])
        let inverse = try ImportedLUTInversePlan(lut: curve, analysisFile: nil,
                                                 interpolation: .tricubicLegacyV1)
        let request = try XCTUnwrap(try? LUTGenerationRequest(
            plan: identityPlan(), size: 2, domain: .unit, inputTransferInverse: inverse))
        XCTAssertNotNil(request)
        XCTAssertThrowsError(try LUTGenerationRequest(
            plan: identityPlan(), size: 2, domain: .unit,
            inputShaper: try CubeShaper(size: 2, domain: .unit,
                                        samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)]),
            inputTransferInverse: inverse)) { error in
            XCTAssertEqual(error as? JobFailure, .conflictingInputTransforms)
        }
    }
}
