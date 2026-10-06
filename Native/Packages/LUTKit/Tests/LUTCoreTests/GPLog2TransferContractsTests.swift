import XCTest
@testable import LUTCore
@testable import LUTCatalog

final class GPLog2TransferContractsTests: XCTestCase {
    func testBase600MatchesIndependentDecimalReference() throws {
        let expected: [(Double, Double)] = [
            (0, 0),
            (0.18, 0.7331165721407825),
            (0.5, 0.8919040948532175),
            (1, 1),
        ]
        for (scene, encoded) in expected {
            XCTAssertEqual(try GPLog2Transfer.encodeSceneToData(scene), encoded, accuracy: 2e-15)
            XCTAssertEqual(try GPLog2Transfer.decodeDataToScene(encoded), scene, accuracy: 3e-15)
        }
    }

    func testBase600RejectsNegativeAndOutOfSubsetValues() throws {
        for value in [-Double.ulpOfOne, -0.1, 1.000001, .nan, .infinity] {
            XCTAssertThrowsError(try GPLog2Transfer.encodeSceneToData(value))
            XCTAssertThrowsError(try GPLog2Transfer.decodeDataToScene(value))
        }
    }

    func testCatalogAndTransformPlanUseDedicatedIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "GoPro GP-Log2 (base 600)")?.id, .gpLog2)
        XCTAssertNotEqual(TransferID.gpLog2, .goProProtuneLUTCalcLegacy)
    }

    func testPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        func planVersion(input: TransferID, output: TransferID,
                         inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> String {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: input, outputTransfer: output,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0
            )).planVersion
        }
        let baseline = try planVersion(input: .gpLog2, output: .linearScene,
                                       inputSpace: .rec2020, outputSpace: .rec2020)
        XCTAssertNotEqual(baseline, try planVersion(input: .linearScene, output: .gpLog2,
                                                    inputSpace: .rec2020, outputSpace: .rec2020))
        XCTAssertNotEqual(baseline, try planVersion(input: .gpLog2, output: .linearScene,
                                                    inputSpace: .displayP3, outputSpace: .rec2020))
        XCTAssertNotEqual(baseline, try planVersion(input: .gpLog2, output: .linearScene,
                                                    inputSpace: .rec2020, outputSpace: .displayP3))
        XCTAssertTrue(baseline.contains("inSpace:rec2020.d65.v1"))
        XCTAssertTrue(baseline.contains("outSpace:rec2020.d65.v1"))
    }
}
