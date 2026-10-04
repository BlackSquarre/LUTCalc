import Foundation
import XCTest
import LUTCore
import LUTFormats
@testable import LUTJobs

final class ILUTExportContractsTests: XCTestCase {
    func testOneDIntegerSinksRejectSignedZeroDomainAtPrepare() async throws {
        let domain = try LUTDomain(min: RGB64(-0.0, 0, 0), max: RGB64(1, 1, 1))
        let ilut = FileILUTSink(target: FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-ilut-domain-\(UUID().uuidString).ilut"))
        do {
            try await ilut.prepare(size: ILUTParser.size, domain: domain, title: "contract")
            XCTFail("ILUT must reject signed zero")
        } catch let error as ILUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        let olut = FileOLUTSink(target: FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-olut-domain-\(UUID().uuidString).olut"))
        do {
            try await olut.prepare(size: OLUTParser.size, domain: domain, title: "contract")
            XCTFail("OLUT must reject signed zero")
        } catch let error as OLUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
    }

    func testSinkRejectsExistingTargetAndCleansUpFailedQuantization() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-ilut-sink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.ilut")
        let original = Data("existing".utf8)
        try original.write(to: target)
        let protected = FileILUTSink(target: target)
        do {
            try await protected.prepare(size: 16_384, domain: .unit, title: "contract")
            XCTFail("Expected targetExists")
        } catch FileSinkError.targetExists {}
        XCTAssertEqual(try Data(contentsOf: target), original)

        try FileManager.default.removeItem(at: target)
        let invalid = FileILUTSink(target: target)
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 1)
        let request = try LUT1DGenerationRequest(plan: TransformPlan(settings: settings),
                                                 size: 16_384, domain: .unit)
        do {
            _ = try await OneDGenerationCoordinator().generate(request, sink: invalid)
            XCTFail("Expected out-of-range output to fail")
        } catch let error as ILUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        let state = await invalid.state
        XCTAssertEqual(state, .aborted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
