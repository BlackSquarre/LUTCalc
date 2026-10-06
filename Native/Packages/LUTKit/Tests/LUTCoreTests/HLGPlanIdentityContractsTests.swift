import XCTest
@testable import LUTCore

final class HLGPlanIdentityContractsTests: XCTestCase {
    private func settings(input: TransferID, output: TransferID,
                          inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) -> TransformSettings {
        TransformSettings(inputTransfer: input, outputTransfer: output,
                          inputSpace: inputSpace, outputSpace: outputSpace,
                          inputRange: .data, outputRange: .data, exposureStops: 0)
    }

    func testHLGPlanIdentityIncludesDirectionAndSpaces() throws {
        let decode = try TransformPlan(settings: settings(input: .rec2100HLG,
                                                           output: .linearScene,
                                                           inputSpace: .rec2020,
                                                           outputSpace: .srgb))
        let encode = try TransformPlan(settings: settings(input: .linearScene,
                                                           output: .rec2100HLG,
                                                           inputSpace: .srgb,
                                                           outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, encode.planVersion)

        let alternate = try TransformPlan(settings: settings(input: .rec2100HLG,
                                                              output: .linearScene,
                                                              inputSpace: .srgb,
                                                              outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
    }

    func testHLGFormulaAndOOTFRemainUnchangedByIdentity() throws {
        let ootf = HLGOOTFSettings(inputPeakNits: 1000, outputPeakNits: 1000,
                                   inputBlackNits: 0, outputBlackNits: 0)
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .rec2100HLG,
                                         inputSpace: .rec2020, outputSpace: .rec2020,
                                         inputRange: .data, outputRange: .data,
                                         exposureStops: 0, hlgOOTF: ootf)
        let plan = try TransformPlan(settings: settings)
        let trace = try plan.trace(RGB64(0.18, 0.18, 0.18))
        XCTAssertEqual(trace.output.r,
                       try HLGTransfer.encodeSceneToData(6.476039825649833 / 1000),
                       accuracy: 2e-14)
    }
}
