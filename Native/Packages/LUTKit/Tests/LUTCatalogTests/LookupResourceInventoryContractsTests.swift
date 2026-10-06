import Foundation
import XCTest
import LUTCatalog

final class LookupResourceInventoryContractsTests: XCTestCase {
    func testDirectLookupSnapshotMatchesBlockedCatalogInventory() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let snapshotURL = repository.appendingPathComponent(
            "research/colour/2026-09-23/current-inventory.json")
        let data = try Data(contentsOf: snapshotURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let gammas = try XCTUnwrap(root["gammas"] as? [[String: Any]])
        let sampled = gammas.filter { $0["sampleTableBased"] as? Bool == true }
        let names = try sampled.map { try XCTUnwrap($0["name"] as? String) }
        let grouped = Dictionary(grouping: sampled) { $0["class"] as? String ?? "" }

        XCTAssertEqual(names.count, 45)
        XCTAssertEqual(grouped["LUTGammaDLog"]?.count, 1)
        XCTAssertEqual(grouped["LUTGammaIOLUT"]?.count, 9)
        XCTAssertEqual(grouped["LUTGammaLUTSL3"]?.count, 10)
        XCTAssertEqual(grouped["LUTGammaLUTSimple"]?.count, 25)
        XCTAssertEqual(Set(names), Set(AlgorithmCatalog.blockedLookupRegistrationNames))
    }

    func testIndirectLabinResourceSnapshotMatchesRepositoryFiles() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let snapshotURL = repository.appendingPathComponent(
            "research/colour/2026-09-23/current-inventory.json")
        let data = try Data(contentsOf: snapshotURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let assets = try XCTUnwrap(root["assets"] as? [[String: Any]])
        let snapshotNames = try assets.map { try XCTUnwrap($0["path"] as? String) }
        let currentNames = try FileManager.default.contentsOfDirectory(atPath: repository.path)
            .filter { $0.hasSuffix(".labin") }

        XCTAssertEqual(snapshotNames.count, 9)
        XCTAssertEqual(Set(currentNames), Set(snapshotNames))
    }
}
