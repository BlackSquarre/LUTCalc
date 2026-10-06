import XCTest
@testable import LUTCore

final class SRGBPlanIdentityContractsTests: XCTestCase {
    private func plan(input: TransferID, output: TransferID,
                      inputSpace: ColorSpaceID = .srgb,
                      outputSpace: ColorSpaceID = .srgb) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: input, outputTransfer: output,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: .data, outputRange: .data, exposureStops: 0
        ))
    }

    func testPublishedAndLegacyTransferPlansHaveDistinctIdentities() throws {
        let published = try plan(input: .srgbW3CExtended, output: .linearScene)
        let legacy = try plan(input: .srgbLUTCalcLegacy, output: .linearScene)

        XCTAssertNotEqual(published.planVersion, legacy.planVersion)
        XCTAssertTrue(published.planVersion.contains(TransferID.srgbW3CExtended.rawValue))
        XCTAssertTrue(legacy.planVersion.contains(TransferID.srgbLUTCalcLegacy.rawValue))
    }

    func testPublishedEncodeAndDecodePlansHaveDistinctIdentities() throws {
        let decode = try plan(input: .srgbW3CExtended, output: .linearScene)
        let encode = try plan(input: .linearScene, output: .srgbW3CExtended)

        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        XCTAssertTrue(decode.planVersion.contains(
            TransferID.srgbW3CExtended.rawValue + ":" + TransferID.linearScene.rawValue))
        XCTAssertTrue(encode.planVersion.contains(
            TransferID.linearScene.rawValue + ":" + TransferID.srgbW3CExtended.rawValue))
    }

    func testLegacyEncodeAndDecodePlansHaveDistinctIdentities() throws {
        let decode = try plan(input: .srgbLUTCalcLegacy, output: .linearScene)
        let encode = try plan(input: .linearScene, output: .srgbLUTCalcLegacy)

        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        XCTAssertTrue(decode.planVersion.contains(
            TransferID.srgbLUTCalcLegacy.rawValue + ":" + TransferID.linearScene.rawValue))
        XCTAssertTrue(encode.planVersion.contains(
            TransferID.linearScene.rawValue + ":" + TransferID.srgbLUTCalcLegacy.rawValue))
    }

    func testPublishedAndLegacyPlanIdentitiesIncludeBothColorSpaces() throws {
        for transfer in [TransferID.srgbW3CExtended, .srgbLUTCalcLegacy] {
            let baseline = try plan(input: transfer, output: .linearScene,
                                    inputSpace: .rec2020, outputSpace: .displayP3)
            let alternateInput = try plan(input: transfer, output: .linearScene,
                                          inputSpace: .srgb, outputSpace: .displayP3)
            let alternateOutput = try plan(input: transfer, output: .linearScene,
                                           inputSpace: .rec2020, outputSpace: .acesAP0)

            XCTAssertNotEqual(baseline.planVersion, alternateInput.planVersion)
            XCTAssertNotEqual(baseline.planVersion, alternateOutput.planVersion)
            XCTAssertTrue(baseline.planVersion.contains(
                ":inSpace:\(ColorSpaceID.rec2020.rawValue):outSpace:\(ColorSpaceID.displayP3.rawValue)"))
        }
    }
}
