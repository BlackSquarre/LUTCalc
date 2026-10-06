import XCTest
@testable import LUTCore

final class AppleARRILogPlanIdentityContractsTests: XCTestCase {
    private func plan(input: TransferID, output: TransferID,
                      inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: input, outputTransfer: output,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            adaptation: .bradford))
    }

    func testAppleAndARRILogPlanIdentityIncludesDirectionAndBothSpaces() throws {
        let cases: [(String, TransferID, ColorSpaceID)] = [
            ("Apple Log", .appleLogOriginal, .rec2020),
            ("Apple Log 2", .appleLog2, .appleWideGamut),
            ("ARRI LogC4", .arriLogC4, .arriWideGamut4)
        ]

        for (name, transfer, nativeSpace) in cases {
            let alternateSpace: ColorSpaceID = nativeSpace == .srgb ? .rec2020 : .srgb
            let decode = try plan(input: transfer, output: .linearScene,
                                  inputSpace: nativeSpace, outputSpace: .acesAP0)
            let encode = try plan(input: .linearScene, output: transfer,
                                  inputSpace: .acesAP0, outputSpace: nativeSpace)
            let alternateInput = try plan(input: transfer, output: .linearScene,
                                          inputSpace: alternateSpace, outputSpace: .acesAP0)
            let alternateOutput = try plan(input: .linearScene, output: transfer,
                                           inputSpace: .acesAP0, outputSpace: alternateSpace)

            XCTAssertNotEqual(decode.planVersion, encode.planVersion, "\(name) direction")
            XCTAssertNotEqual(decode.planVersion, alternateInput.planVersion, "\(name) input space")
            XCTAssertNotEqual(encode.planVersion, alternateOutput.planVersion, "\(name) output space")
            XCTAssertTrue(decode.planVersion.contains(transfer.rawValue), "\(name) transfer")
            XCTAssertTrue(decode.planVersion.contains(nativeSpace.rawValue), "\(name) input gamut")
            XCTAssertTrue(decode.planVersion.contains(ColorSpaceID.acesAP0.rawValue), "\(name) output gamut")
        }
    }
}
