import XCTest
import LUTCore
import LUTFormats
import LUTJobs

final class GenerationContractsTests: XCTestCase {
    func testDifferentWorkersAndBlocksHaveIdenticalSamples() async throws {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        ))
        let expected = try CubeGenerator.generate3D(plan: plan, size: 17, domain: .unit).samples
        for workers in [1, 2, 4] {
            for blockSize in [1, 17, 4096] {
                let sink = InMemoryCubeSink()
                let request = try LUTGenerationRequest(plan: plan, size: 17, domain: .unit, blockNodes: blockSize, workerCount: workers)
                let report = try await GenerationCoordinator().generate(request, sink: sink)
                XCTAssertEqual(report.writtenNodes, expected.count)
                XCTAssertLessThanOrEqual(report.maxPendingBlocks, 2 * workers)
                let samples = await sink.samples
                let state = await sink.state
                XCTAssertEqual(samples, expected)
                XCTAssertEqual(state, .committed)
            }
        }
    }

    func testWriteFailureAbortsWithoutCommit() async throws {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        ))
        let request = try LUTGenerationRequest(plan: plan, size: 3, domain: .unit, blockNodes: 3, workerCount: 2)
        let sink = InMemoryCubeSink(failAtBlock: 2)
        do {
            _ = try await GenerationCoordinator().generate(request, sink: sink)
            XCTFail("Expected injected write failure")
        } catch JobFailure.injectedWriteFailure {}
        let state = await sink.state
        let samples = await sink.samples
        XCTAssertEqual(state, .aborted)
        XCTAssertTrue(samples.isEmpty)
    }

    func testUnitOneDimensionalUserLUTIsAppliedAsPostStage() async throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let plan = try TransformPlan(settings: settings)
        let user = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                               samples: [try RGB64(0, 0, 0), try RGB64(0.25, 0.5, 0.75)])
        let request = try LUTGenerationRequest(plan: plan, size: 2, domain: .unit,
                                                blockNodes: 8, workerCount: 1, postLUT: user)
        let sink = InMemoryCubeSink()
        _ = try await GenerationCoordinator().generate(request, sink: sink)
        let samples = await sink.samples
        XCTAssertEqual(samples.count, 8)
        XCTAssertEqual(samples[0], try RGB64(0, 0, 0))
        XCTAssertEqual(samples[7], try RGB64(0.25, 0.5, 0.75))
    }
}
