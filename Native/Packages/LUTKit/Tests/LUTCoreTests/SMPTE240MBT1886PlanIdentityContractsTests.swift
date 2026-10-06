import XCTest
@testable import LUTCore

final class SMPTE240MBT1886PlanIdentityContractsTests: XCTestCase {
    private func plan(input: TransferID, output: TransferID,
                      inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: input, outputTransfer: output,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            rangeBitDepth: 10
        ))
    }

    func testSMPTE240MIdentityIncludesDirectionAndBothSpaces() throws {
        let decode = try plan(input: .smpte240M, output: .linearScene,
                              inputSpace: .smpte240M, outputSpace: .srgb)
        let encode = try plan(input: .linearScene, output: .smpte240M,
                              inputSpace: .srgb, outputSpace: .smpte240M)
        let alternateInput = try plan(input: .smpte240M, output: .linearScene,
                                      inputSpace: .rec2020, outputSpace: .srgb)
        let alternateOutput = try plan(input: .smpte240M, output: .linearScene,
                                       inputSpace: .smpte240M, outputSpace: .displayP3)

        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        XCTAssertNotEqual(decode.planVersion, alternateInput.planVersion)
        XCTAssertNotEqual(decode.planVersion, alternateOutput.planVersion)
    }

    func testBT1886IdentityIncludesDirectionAndBothSpaces() throws {
        let decode = try plan(input: .bt1886, output: .linearScene,
                              inputSpace: .rec2020, outputSpace: .srgb)
        let encode = try plan(input: .linearScene, output: .bt1886,
                              inputSpace: .srgb, outputSpace: .rec2020)
        let alternateInput = try plan(input: .bt1886, output: .linearScene,
                                      inputSpace: .displayP3, outputSpace: .srgb)
        let alternateOutput = try plan(input: .bt1886, output: .linearScene,
                                       inputSpace: .rec2020, outputSpace: .displayP3)

        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        XCTAssertNotEqual(decode.planVersion, alternateInput.planVersion)
        XCTAssertNotEqual(decode.planVersion, alternateOutput.planVersion)
    }
}
