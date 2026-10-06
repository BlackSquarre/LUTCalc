import Foundation
import XCTest
@testable import LUTCore
@testable import LUTCatalog
@testable import LUTProject

final class ACESReferenceGamutCompressionProjectContractsTests: XCTestCase {
    private let catalog = try! AlgorithmCatalog.builtIn()

    private func settings(with compression: ACESReferenceGamutCompressionSettings? = nil) -> TransformSettings {
        TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .linearScene,
            inputSpace: .acesAP0,
            outputSpace: .acesAP0,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            acesReferenceGamutCompression: compression
        )
    }

    func testRGCManifestRoundTripsThroughCurrentSchema() throws {
        let compression = ACESReferenceGamutCompressionSettings(operation: .compress)
        let manifest = ProjectManifest(settings: settings(with: compression), cubeSize: 33, domain: .unit)
        XCTAssertEqual(manifest.schemaVersion, ProjectManifest.currentSchema)
        XCTAssertEqual(manifest.algorithmVersions["acesReferenceGamutCompression"],
                       ACESReferenceGamutCompression.algorithm)
        let data = try ProjectCodec.encode(manifest, catalog: catalog)
        let decoded = try ProjectCodec.decode(data, catalog: catalog)
        XCTAssertEqual(decoded, manifest)
    }

    func testSchema25WithoutRGCFieldRemainsReadable() throws {
        let manifest = ProjectManifest(settings: settings(), cubeSize: 17, domain: .unit)
        var object = try JSONSerialization.jsonObject(
            with: ProjectCodec.encode(manifest, catalog: catalog)
        ) as! [String: Any]
        object["schemaVersion"] = 25
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try ProjectCodec.decode(data, catalog: catalog)
        XCTAssertNil(decoded.settings.acesReferenceGamutCompression)
    }

    func testSchema25CannotHideRGCField() throws {
        let compression = ACESReferenceGamutCompressionSettings(operation: .compress)
        let manifest = ProjectManifest(settings: settings(with: compression), cubeSize: 17, domain: .unit)
        var object = try JSONSerialization.jsonObject(
            with: ProjectCodec.encode(manifest, catalog: catalog)
        ) as! [String: Any]
        object["schemaVersion"] = 25
        XCTAssertThrowsError(try ProjectCodec.decode(
            JSONSerialization.data(withJSONObject: object), catalog: catalog
        ))
    }
}
