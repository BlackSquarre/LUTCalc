import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class UserLUTInverseProjectContractsTests: XCTestCase {
    private func settings() -> TransformSettings {
        TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                          inputSpace: .acesAP0, outputSpace: .acesAP0,
                          inputRange: .data, outputRange: .data, exposureStops: 0)
    }

    func testInputInverseMetadataRoundTripsAndIsBoundToUserAsset() throws {
        let path = "Resources/user-00000000-0000-0000-0000-000000000001.cube"
        let metadata = UserLUTInputInverseSettings(assetPath: path,
                                                   interpolation: .tricubicLegacyV1)
        let bytes = Data("{}".utf8)
        let manifest = ProjectManifest(settings: settings(), cubeSize: 17, domain: .unit,
                                       assetHashes: [path: ProjectAssets.sha256(of: bytes)],
                                       assetRoles: [path: .userLUT],
                                       userLUTInputInverse: metadata)
        let catalog = try AlgorithmCatalog.builtIn()
        let decoded = try ProjectCodec.decode(try ProjectCodec.encode(manifest, catalog: catalog),
                                              catalog: catalog)
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.userLUTInputInverse, metadata)

        var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(manifest, catalog: catalog))
            as! [String: Any]
        raw["userLUTInputInverse"] = ["assetPath": "Resources/other.cube",
                                       "interpolation": "tricubicLegacyV1"]
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw),
                                                     catalog: catalog)) { error in
            XCTAssertEqual(error as? ProjectError, .invalidAssetRoles)
        }
    }
}
