import XCTest
@testable import LUTCore
@testable import LUTCatalog

/// 纯算法接线契约：注册表中的独立 transfer 必须真正经过 TransformPlan。
final class TransformAlgorithmWiringContractsTests: XCTestCase {
    private func plan(input: TransferID, output: TransferID,
                      space: ColorSpaceID = .rec2020) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: input,
            outputTransfer: output,
            inputSpace: space,
            outputSpace: space,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0
        ))
    }

    func testGPLog2UsesDedicatedPlanDecoderAndEncoder() throws {
        let plan = try plan(input: .gpLog2, output: .gpLog2)
        XCTAssertEqual(plan.planVersion,
                       "minimal-gopro-gplog2-base600-v1:gopro.gplog2-base600.v1:gopro.gplog2-base600.v1:inSpace:rec2020.d65.v1:outSpace:rec2020.d65.v1")
        for value in [0.0, 0.18, 0.5, 1.0] {
            let output = try plan.evaluate(RGB64(value, value, value))
            XCTAssertEqual(output.r, value, accuracy: 3e-15)
            XCTAssertEqual(output.g, value, accuracy: 3e-15)
            XCTAssertEqual(output.b, value, accuracy: 3e-15)
        }
    }

    func testContinuousBT2020UsesDedicatedPlanDecoderAndEncoder() throws {
        let plan = try plan(input: .rec2020Continuous, output: .rec2020Continuous)
        XCTAssertTrue(plan.planVersion.contains("minimal-rec2020-continuous-v1"))
        for value in [0.0, 0.01, 0.018053968510807, 0.18, 1.0] {
            let output = try plan.evaluate(RGB64(value, value, value))
            XCTAssertEqual(output.r, value, accuracy: 4e-15)
            XCTAssertEqual(output.g, value, accuracy: 4e-15)
            XCTAssertEqual(output.b, value, accuracy: 4e-15)
        }
    }

    func testCatalogTransferIDsRemainDistinctFromLegacyWrappers() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "GoPro GP-Log2 (base 600)")?.id, .gpLog2)
        XCTAssertEqual(catalog.transfer(named: "Rec.2020 continuous")?.id, .rec2020Continuous)
        XCTAssertNotEqual(TransferID.gpLog2, .goProProtuneLUTCalcLegacy)
        XCTAssertNotEqual(TransferID.rec2020Continuous, .rec2020TenBit)
    }

    func testLinearScenePlanIdentityIncludesBothColorSpaces() throws {
        let baseline = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )).planVersion
        let inputChanged = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .displayP3, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )).planVersion
        let outputChanged = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .displayP3,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )).planVersion
        XCTAssertNotEqual(baseline, inputChanged)
        XCTAssertNotEqual(baseline, outputChanged)
        XCTAssertTrue(baseline.contains("inSpace:rec2020.d65.v1"))
        XCTAssertTrue(baseline.contains("outSpace:rec2020.d65.v1"))
    }

    func testPublishedAndLegacySLog3PlansDoNotShareIdentity() throws {
        let published = try plan(input: .sonySLog3, output: .sonySLog3)
        let legacy = try plan(input: .sonySLog3LUTCalcLegacy, output: .sonySLog3LUTCalcLegacy)
        XCTAssertNotEqual(published.planVersion, legacy.planVersion,
                          "published and LUTCalc legacy S-Log3 must not share a cache identity")
        XCTAssertTrue(published.planVersion.contains(TransferID.sonySLog3.rawValue))
        XCTAssertTrue(legacy.planVersion.contains(TransferID.sonySLog3LUTCalcLegacy.rawValue))
    }

    func testSLog3PlansIncludeBothPublishedGamutIdentities() throws {
        let cine = try TransformPlan(settings: TransformSettings(
            inputTransfer: .sonySLog3, outputTransfer: .linearScene,
            inputSpace: .sonySGamut3Cine, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        let wide = try TransformPlan(settings: TransformSettings(
            inputTransfer: .sonySLog3, outputTransfer: .linearScene,
            inputSpace: .sonySGamut3, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        XCTAssertNotEqual(cine.planVersion, wide.planVersion,
                          "S-Log3 plans with different published gamuts must not share a cache identity")
        XCTAssertTrue(cine.planVersion.contains(ColorSpaceID.sonySGamut3Cine.rawValue))
        XCTAssertTrue(wide.planVersion.contains(ColorSpaceID.sonySGamut3.rawValue))
        XCTAssertTrue(cine.planVersion.contains(ColorSpaceID.acesAP0.rawValue))
        XCTAssertTrue(wide.planVersion.contains(ColorSpaceID.acesAP0.rawValue))
    }

    func testDirectionalTransferPlansDoNotAlias() throws {
        let pairs: [(TransferID, String)] = [
            (.gpLog2, "minimal-gopro-gplog2-base600-v1"),
            (.rec2020Continuous, "minimal-rec2020-continuous-v1"),
            (.rec2100HLG, "minimal-rec2100-hlg-v1"),
            (.acesCC, "minimal-acescc-v1")
        ]
        for (transfer, family) in pairs {
            let forward = try plan(input: transfer, output: .linearScene)
            let reverse = try plan(input: .linearScene, output: transfer)
            XCTAssertNotEqual(forward.planVersion, reverse.planVersion)
            XCTAssertTrue(forward.planVersion.contains(family))
            XCTAssertTrue(reverse.planVersion.contains(family))
            XCTAssertTrue(forward.planVersion.contains(transfer.rawValue))
            XCTAssertTrue(reverse.planVersion.contains(transfer.rawValue))
        }
    }

    func testACESDirectionalPlansIncludeBothTransferIDs() throws {
        let forward = try TransformPlan(settings: TransformSettings(
            inputTransfer: .acesCC, outputTransfer: .linearScene,
            inputSpace: .acesAP1, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        let reverse = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .acesCC,
            inputSpace: .acesAP1, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0))

        XCTAssertNotEqual(forward.planVersion, reverse.planVersion)
        XCTAssertTrue(forward.planVersion.contains(TransferID.acesCC.rawValue))
        XCTAssertTrue(forward.planVersion.contains(TransferID.linearScene.rawValue))
        XCTAssertTrue(reverse.planVersion.contains(TransferID.linearScene.rawValue))
    }
}
