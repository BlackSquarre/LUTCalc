import XCTest
@testable import LUTCore

final class VLogPlanIdentityContractsTests: XCTestCase {
    private func plan(input: TransferID, output: TransferID,
                      inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: input, outputTransfer: output,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: .data, outputRange: .data, exposureStops: 0))
    }

    func testDirectionAndGamutArePartOfVLogPlanIdentity() throws {
        let forward = try plan(input: .panasonicVLog, output: .linearScene,
                               inputSpace: .panasonicVGamut, outputSpace: .rec2020)
        let reverse = try plan(input: .linearScene, output: .panasonicVLog,
                               inputSpace: .rec2020, outputSpace: .panasonicVGamut)
        XCTAssertNotEqual(forward.planVersion, reverse.planVersion)
        XCTAssertTrue(forward.planVersion.contains(":panasonic.vlog.v1:linear.scene.v1:inSpace:panasonic.vgamut.v1:outSpace:rec2020.d65.v1"))
        XCTAssertTrue(reverse.planVersion.contains(":linear.scene.v1:panasonic.vlog.v1:inSpace:rec2020.d65.v1:outSpace:panasonic.vgamut.v1"))
    }

    func testDifferentGamutDoesNotAliasVLogPlan() throws {
        let native = try plan(input: .panasonicVLog, output: .linearScene,
                              inputSpace: .panasonicVGamut, outputSpace: .rec2020)
        let alternate = try plan(input: .panasonicVLog, output: .linearScene,
                                 inputSpace: .rec2020, outputSpace: .rec2020)
        XCTAssertNotEqual(native.planVersion, alternate.planVersion)
    }
}
