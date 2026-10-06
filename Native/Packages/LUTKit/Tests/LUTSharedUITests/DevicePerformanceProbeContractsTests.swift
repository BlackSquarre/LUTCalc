import Foundation
import XCTest
import LUTSharedUI

final class DevicePerformanceProbeContractsTests: XCTestCase {
    func testProbeUsesStableSchemaNodesAndBitPatternChecksums() throws {
        let result = try DevicePerformanceProbe.run(sizes: [2, 3])

        XCTAssertEqual(result.schema, "native.device-performance.v1")
        XCTAssertEqual(result.planVersion,
                       "minimal-linear-scene-v1:dji.dlog2.v1:linear.scene.v1:inSpace:dji.dgamut2.v1:outSpace:aces.ap0.v1")
        XCTAssertEqual(result.results.map(\.size), [2, 3])
        XCTAssertEqual(result.results.map(\.nodes), [8, 27])
        XCTAssertEqual(result.results.map(\.checksum), [
            178_067_521_371_958_758,
            14_729_761_063_298_853_721
        ])
        XCTAssertTrue(result.results.allSatisfy { $0.seconds >= 0 && $0.nodesPerSecond >= 0 })
    }

    func testProbeRejectsInvalidOrDuplicateSizes() {
        XCTAssertThrowsError(try DevicePerformanceProbe.run(sizes: []))
        XCTAssertThrowsError(try DevicePerformanceProbe.run(sizes: [1]))
        XCTAssertThrowsError(try DevicePerformanceProbe.run(sizes: [2, 2]))
    }

    func testProbeJSONRoundTripsWithoutDroppingMeasurements() throws {
        let result = try DevicePerformanceProbe.run(sizes: [2])
        let decoded = try JSONDecoder().decode(DevicePerformanceProbeResult.self,
                                                from: JSONEncoder().encode(result))
        XCTAssertEqual(decoded, result)
    }

    func testRepeatedProbeReportsEverySampleAndDeterministicSummary() throws {
        let result = try DevicePerformanceProbe.runRepeated(sizes: [2], repetitions: 3, warmups: 1)

        XCTAssertEqual(result.schema, "native.device-performance-repeat.v1")
        XCTAssertEqual(result.warmups, 1)
        XCTAssertEqual(result.repetitions, 3)
        XCTAssertEqual(result.measurements.count, 1)
        XCTAssertEqual(result.measurements[0].size, 2)
        XCTAssertEqual(result.measurements[0].nodes, 8)
        XCTAssertEqual(result.measurements[0].seconds.count, 3)
        XCTAssertEqual(result.measurements[0].checksum, 178_067_521_371_958_758)
        XCTAssertEqual(result.measurements[0].minimumSeconds,
                       result.measurements[0].seconds.min()!)
        XCTAssertEqual(result.measurements[0].maximumSeconds,
                       result.measurements[0].seconds.max()!)
        XCTAssertTrue(result.measurements[0].medianSeconds >= result.measurements[0].minimumSeconds)
        XCTAssertTrue(result.measurements[0].medianSeconds <= result.measurements[0].maximumSeconds)
    }

    func testRepeatedProbeRejectsInvalidRepetitionAndWarmupCounts() {
        XCTAssertThrowsError(try DevicePerformanceProbe.runRepeated(sizes: [2], repetitions: 0))
        XCTAssertThrowsError(try DevicePerformanceProbe.runRepeated(sizes: [2], repetitions: 1, warmups: -1))
    }

    func testRepeatedProbeStopsBeforeWorkWhenCancellationIsRequested() {
        var checks = 0
        XCTAssertThrowsError(try DevicePerformanceProbe.runRepeated(
            sizes: [2, 3], repetitions: 2, warmups: 0,
            shouldCancel: {
                checks += 1
                return checks >= 1
            })) { error in
            XCTAssertEqual(error as? DevicePerformanceProbeError, .cancelled)
        }
        XCTAssertEqual(checks, 1)
    }

    func testRepeatedProbeKeepsProductionGridSizesAndNodeCounts() throws {
        let result = try DevicePerformanceProbe.runRepeated(
            sizes: [17, 33, 65], repetitions: 1, warmups: 0)
        XCTAssertEqual(result.measurements.map(\.size), [17, 33, 65])
        XCTAssertEqual(result.measurements.map(\.nodes), [4_913, 35_937, 274_625])
        XCTAssertTrue(result.measurements.allSatisfy { $0.seconds.count == 1 })
    }
}
