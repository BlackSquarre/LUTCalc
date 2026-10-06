import XCTest
@testable import LUTCore

final class Rec709Rec2020PQPlanIdentityContractsTests: XCTestCase {
    private func settings(input: TransferID, output: TransferID,
                          inputSpace: ColorSpaceID = .rec2020,
                          outputSpace: ColorSpaceID = .rec2020) -> TransformSettings {
        TransformSettings(inputTransfer: input, outputTransfer: output,
                          inputSpace: inputSpace, outputSpace: outputSpace,
                          inputRange: .data, outputRange: .data, exposureStops: 0)
    }

    func testRec709PlanIdentityIncludesDirectionAndSpaces() throws {
        let decode = try TransformPlan(settings: settings(input: .rec709LUTCalcLegacy,
                                                           output: .linearScene,
                                                           inputSpace: .rec2020,
                                                           outputSpace: .srgb))
        let encode = try TransformPlan(settings: settings(input: .linearScene,
                                                           output: .rec709LUTCalcLegacy,
                                                           inputSpace: .srgb,
                                                           outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        let alternate = try TransformPlan(settings: settings(input: .rec709LUTCalcLegacy,
                                                              output: .linearScene,
                                                              inputSpace: .srgb,
                                                              outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
    }

    func testRec2020TenBitPlanIdentityIncludesDirectionAndSpaces() throws {
        let decode = try TransformPlan(settings: settings(input: .rec2020TenBit,
                                                           output: .linearScene,
                                                           inputSpace: .rec2020,
                                                           outputSpace: .srgb))
        let encode = try TransformPlan(settings: settings(input: .linearScene,
                                                           output: .rec2020TenBit,
                                                           inputSpace: .srgb,
                                                           outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        let alternate = try TransformPlan(settings: settings(input: .rec2020TenBit,
                                                              output: .linearScene,
                                                              inputSpace: .srgb,
                                                              outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
    }

    func testPQPlanIdentityIncludesDirectionAndSpaces() throws {
        let decode = try TransformPlan(settings: settings(input: .rec2100PQ,
                                                           output: .linearScene,
                                                           inputSpace: .rec2020,
                                                           outputSpace: .srgb))
        let encode = try TransformPlan(settings: settings(input: .linearScene,
                                                           output: .rec2100PQ,
                                                           inputSpace: .srgb,
                                                           outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        let alternate = try TransformPlan(settings: settings(input: .rec2100PQ,
                                                              output: .linearScene,
                                                              inputSpace: .srgb,
                                                              outputSpace: .rec2020))
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
    }
}
