import XCTest
@testable import LUTCore
@testable import LUTCatalog

final class Rec2020ContinuousContractsTests: XCTestCase {
    func testPublishedContinuousBT2020OETF() throws {
        XCTAssertEqual(try Rec2020ContinuousTransfer.encodeSceneToData(0.018053968510807),
                       0.081242858298635, accuracy: 2e-15)
        let values = [0.0, 0.01, 0.018053968510807, 0.18, 1.0]
        for value in values {
            let encoded = try Rec2020ContinuousTransfer.encodeSceneToData(value)
            XCTAssertEqual(try Rec2020ContinuousTransfer.decodeDataToScene(encoded), value, accuracy: 3e-15)
        }
        XCTAssertThrowsError(try Rec2020ContinuousTransfer.encodeSceneToData(.nan))
    }

    func testCatalogIdentityIsSeparateFromPracticalTenBit() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Rec.2020 continuous")?.id, .rec2020Continuous)
        XCTAssertNotEqual(TransferID.rec2020Continuous, .rec2020TenBit)
        XCTAssertEqual(catalog.preset(named: "rec2020.continuous-exposure-one.v1")?.settings.inputTransfer,
                       .rec2020Continuous)
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
        let baseline = try planVersion(input: .rec2020Continuous, output: .linearScene,
                                       inputSpace: .rec2020, outputSpace: .rec2020)
        XCTAssertNotEqual(baseline, try planVersion(input: .linearScene, output: .rec2020Continuous,
                                                    inputSpace: .rec2020, outputSpace: .rec2020))
        XCTAssertNotEqual(baseline, try planVersion(input: .rec2020Continuous, output: .linearScene,
                                                    inputSpace: .displayP3, outputSpace: .rec2020))
        XCTAssertNotEqual(baseline, try planVersion(input: .rec2020Continuous, output: .linearScene,
                                                    inputSpace: .rec2020, outputSpace: .displayP3))
        XCTAssertTrue(baseline.contains("inSpace:rec2020.d65.v1"))
        XCTAssertTrue(baseline.contains("outSpace:rec2020.d65.v1"))
    }
}
