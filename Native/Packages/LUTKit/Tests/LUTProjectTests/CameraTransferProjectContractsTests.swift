import Foundation
import XCTest
import LUTCore
import LUTCatalog
@testable import LUTProject

final class CameraTransferProjectContractsTests: XCTestCase {
    func testFourAlgorithmIdentitiesSurviveProjectDiskRoundTrip() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("camera-transfers-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for id in [TransferID.nikonNLog, .nikonNLogLUTCalcLegacy, .cineon, .cineonLUTCalcLegacy] {
            let settings = TransformSettings(inputTransfer: id, outputTransfer: id,
                inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .video, exposureStops: 0.5)
            let manifest = ProjectManifest(settings: settings, cubeSize: 65, domain: .unit)
            let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
            let url = directory.appendingPathComponent(id.rawValue + ".json")
            try bytes.write(to: url)
            let read = try ProjectCodec.decode(Data(contentsOf: url), catalog: catalog)
            XCTAssertEqual(read.settings, settings)
            XCTAssertEqual(read.cubeSize, 65)
            XCTAssertTrue(try TransformPlan(settings: read.settings).planVersion.contains(id.rawValue))
        }
    }
}
