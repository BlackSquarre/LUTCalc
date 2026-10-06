import Foundation
import XCTest
@testable import LUTCore

final class ACESReferenceGamutCompressionPlanContractsTests: XCTestCase {
    private func baseSettings() -> TransformSettings {
        TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .linearScene,
            inputSpace: .acesAP0,
            outputSpace: .acesAP0,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0
        )
    }

    func testPlanAppliesRGCInLinearACESAP0AtStageSeven() throws {
        let input = try RGB64(1.2, -0.1, 0.05)
        let settings = baseSettings().withACESReferenceGamutCompression(
            ACESReferenceGamutCompressionSettings(operation: .compress)
        )
        let plan = try TransformPlan(settings: settings)
        let expected = try ACESReferenceGamutCompression().compress(input)
        let actual = try plan.evaluate(input)
        XCTAssertEqual(actual.r, expected.r, accuracy: 3e-12)
        XCTAssertEqual(actual.g, expected.g, accuracy: 3e-12)
        XCTAssertEqual(actual.b, expected.b, accuracy: 3e-12)
        let trace = try plan.trace(input)
        let stage = try XCTUnwrap(trace.stages.first { $0.id == 75 })
        XCTAssertEqual(stage.inputSpace, .acesAP0)
        XCTAssertEqual(stage.outputSpace, .acesAP0)
        XCTAssertEqual(stage.output.r, actual.r, accuracy: 3e-12)
        XCTAssertEqual(stage.output.g, actual.g, accuracy: 3e-12)
        XCTAssertEqual(stage.output.b, actual.b, accuracy: 3e-12)
        XCTAssertTrue(plan.planVersion.contains(ACESReferenceGamutCompression.algorithm))
    }

    func testPlanSupportsExplicitRGCDecompression() throws {
        let source = try RGB64(1.2, -0.1, 0.05)
        let compressed = try ACESReferenceGamutCompression().compress(source)
        let settings = baseSettings().withACESReferenceGamutCompression(
            ACESReferenceGamutCompressionSettings(operation: .decompress)
        )
        let recovered = try TransformPlan(settings: settings).evaluate(compressed)
        XCTAssertEqual(recovered.r, source.r, accuracy: 2e-9)
        XCTAssertEqual(recovered.g, source.g, accuracy: 2e-9)
        XCTAssertEqual(recovered.b, source.b, accuracy: 2e-9)
    }

    func testRGCRejectsNonLinearOrCoupledPlans() throws {
        let nonLinear = TransformSettings(
            inputTransfer: .srgbW3CExtended,
            outputTransfer: .linearScene,
            inputSpace: .acesAP0,
            outputSpace: .acesAP0,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0
        ).withACESReferenceGamutCompression(
            ACESReferenceGamutCompressionSettings(operation: .compress)
        )
        XCTAssertThrowsError(try TransformPlan(settings: nonLinear))

        let coupled = try baseSettings().withACESReferenceGamutCompression(
            ACESReferenceGamutCompressionSettings(operation: .compress)
        ).withASCCDL(ASCCDLSettings(
            enabled: true,
            slope: try RGB64(1, 1, 1),
            offset: try RGB64(0, 0, 0),
            power: try RGB64(1, 1, 1),
            saturation: 1
        ))
        XCTAssertThrowsError(try TransformPlan(settings: coupled))
    }

    func testRGCSettingsRoundTripAndDisabledIdentity() throws {
        let enabled = baseSettings().withACESReferenceGamutCompression(
            ACESReferenceGamutCompressionSettings(operation: .compress)
        )
        let data = try JSONEncoder().encode(enabled)
        let decoded = try JSONDecoder().decode(TransformSettings.self, from: data)
        XCTAssertEqual(decoded, enabled)
        XCTAssertEqual(decoded.acesReferenceGamutCompression?.algorithm,
                       ACESReferenceGamutCompression.algorithm)

        let disabled = baseSettings().withACESReferenceGamutCompression(nil)
        let input = try RGB64(1.2, -0.1, 0.05)
        XCTAssertEqual(try TransformPlan(settings: disabled).evaluate(input), input)
    }
}
