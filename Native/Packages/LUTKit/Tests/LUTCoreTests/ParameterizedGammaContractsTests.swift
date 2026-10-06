import XCTest
@testable import LUTCore

final class ParameterizedGammaContractsTests: XCTestCase {
    func testParameterizedGammaPlanIdentityIncludesExactDirectionalParameters() throws {
        let inputA = try ParameterizedGammaSettings(
            exponent: 2.200000000000001, linearSlope: 4.5, offset: 0.1,
            linearCut: 0.02)
        let inputB = try ParameterizedGammaSettings(
            exponent: 2.2, linearSlope: 4.5, offset: 0.1,
            linearCut: 0.02)
        let output = try ParameterizedGammaSettings(
            exponent: 2.4, linearSlope: 4.5, offset: 0.1,
            linearCut: 0.02, encodedCut: 0.09)

        func plan(input: ParameterizedGammaSettings?, output: ParameterizedGammaSettings?) throws -> TransformPlan {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: input == nil ? .linearScene : .parameterizedGamma,
                outputTransfer: output == nil ? .linearScene : .parameterizedGamma,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0,
                inputGamma: input, outputGamma: output))
        }

        let decodeA = try plan(input: inputA, output: nil)
        let decodeB = try plan(input: inputB, output: nil)
        let encodeA = try plan(input: nil, output: output)
        let encodeOther = try plan(input: nil, output: inputA)
        XCTAssertNotEqual(decodeA.planVersion, decodeB.planVersion)
        XCTAssertNotEqual(encodeA.planVersion, encodeOther.planVersion)
        XCTAssertNotEqual(decodeA.planVersion, encodeA.planVersion)

        let value = try RGB64(0.4, 0.4, 0.4)
        XCTAssertNotEqual(try decodeA.evaluate(value).r, try decodeB.evaluate(value).r)
        XCTAssertNotEqual(try encodeA.evaluate(value).r, try encodeOther.evaluate(value).r)
    }

    func testParameterizedGammaPlanIdentityIncludesBothColorSpaces() throws {
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.2, linearSlope: 4.5, offset: 0.1, linearCut: 0.02)
        func plan(inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> String {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0,
                inputGamma: gamma, outputGamma: gamma
            )).planVersion
        }
        let baseline = try plan(inputSpace: .srgb, outputSpace: .srgb)
        XCTAssertNotEqual(baseline, try plan(inputSpace: .acesAP0, outputSpace: .srgb))
        XCTAssertNotEqual(baseline, try plan(inputSpace: .srgb, outputSpace: .acesAP0))
    }

    func testImplicitAndEquivalentExplicitEncodedCutSharePlanIdentity() throws {
        let implicit = try ParameterizedGammaSettings(
            exponent: 2.4, linearSlope: 4.5, offset: 0.1, linearCut: 0.02)
        let explicit = try ParameterizedGammaSettings(
            exponent: 2.4, linearSlope: 4.5, offset: 0.1, linearCut: 0.02,
            encodedCut: 0.09)
        func plan(_ gamma: ParameterizedGammaSettings) throws -> TransformPlan {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0,
                inputGamma: gamma, outputGamma: gamma))
        }
        XCTAssertEqual(try plan(implicit).planVersion, try plan(explicit).planVersion)
    }

    func testRangeDepthAndAdaptationEditsPreserveParameterizedGammaSlots() throws {
        let gamma = try ParameterizedGammaSettings(exponent: 2.2, linearSlope: 1,
                                                   offset: 0, linearCut: 0)
        let initial = TransformSettings(
            inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
            inputSpace: .srgb, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            inputGamma: gamma, outputGamma: gamma)
        let changed = initial.withOutputRange(.video)
            .withRangeBitDepth(12).withAdaptation(.bradford)
        XCTAssertEqual(changed.outputRange, .video)
        XCTAssertEqual(changed.rangeBitDepth, 12)
        XCTAssertEqual(changed.adaptation, .bradford)
        XCTAssertEqual(changed.inputGamma, gamma)
        XCTAssertEqual(changed.outputGamma, gamma)
        _ = try TransformPlan(settings: changed)
        XCTAssertThrowsError(try TransformPlan(settings: changed.withRangeBitDepth(16)))
    }
    func testUnrelatedSettingEditsPreserveBothGammaSlotsAndOutputSwitchClearsOnlyOutput() throws {
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.2, linearSlope: 4.5, offset: 0.1, linearCut: 0.02)
        let initial = TransformSettings(
            inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 1,
            adaptation: .bradford, inputGamma: gamma, outputGamma: gamma)
        let changedRange = initial.withInputRange(.video)
        let changedExposure = changedRange.withExposureStops(2)
        XCTAssertEqual(changedExposure.inputGamma, gamma)
        XCTAssertEqual(changedExposure.outputGamma, gamma)
        XCTAssertEqual(changedExposure.adaptation, .bradford)
        XCTAssertEqual(changedExposure.inputRange, .video)
        XCTAssertEqual(changedExposure.exposureStops, 2)
        try changedExposure.validateParameterizedTransfers()
        let switchedOutput = changedExposure.withOutput(transfer: .linearScene, space: .acesAP0)
        XCTAssertEqual(switchedOutput.inputGamma, gamma)
        XCTAssertNil(switchedOutput.outputGamma)
        XCTAssertEqual(switchedOutput.outputTransfer, .linearScene)
        try switchedOutput.validateParameterizedTransfers()
    }

    func testCatalogSelectionRetainsGammaOnlyForTheSelectedTransfer() throws {
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.2, linearSlope: 4.5, offset: 0.1, linearCut: 0.02)
        let initial = TransformSettings(
            inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            inputGamma: gamma, outputGamma: gamma)

        let inputSpaceOnly = initial.withInput(transfer: .parameterizedGamma, space: .rec2020)
        XCTAssertEqual(inputSpaceOnly.inputGamma, gamma)
        XCTAssertEqual(inputSpaceOnly.outputGamma, gamma)
        XCTAssertEqual(inputSpaceOnly.inputSpace, .rec2020)

        let inputTransferChanged = inputSpaceOnly.withInput(transfer: .djiDLog2, space: .djiDGamut2)
        XCTAssertNil(inputTransferChanged.inputGamma)
        XCTAssertEqual(inputTransferChanged.outputGamma, gamma)
        XCTAssertEqual(inputTransferChanged.inputTransfer, .djiDLog2)
        XCTAssertEqual(inputTransferChanged.inputSpace, .djiDGamut2)
        try inputTransferChanged.validateParameterizedTransfers()

        let outputSpaceOnly = inputTransferChanged.withOutput(transfer: .parameterizedGamma, space: .rec2020)
        XCTAssertEqual(outputSpaceOnly.outputGamma, gamma)
        XCTAssertNil(outputSpaceOnly.inputGamma)
        let outputTransferChanged = outputSpaceOnly.withOutput(transfer: .linearScene, space: .acesAP0)
        XCTAssertNil(outputTransferChanged.outputGamma)
        try outputTransferChanged.validateParameterizedTransfers()
    }
    func testParameterizedGammaSettingsRoundTripAndPlanUsesPersistedParameters() throws {
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.4,
            linearSlope: 4.5,
            offset: 0.1,
            linearCut: 0.02,
            encodedCut: 0.09
        )
        let settings = TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .parameterizedGamma,
            inputSpace: .srgb,
            outputSpace: .srgb,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            outputGamma: gamma
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TransformSettings.self, from: data)
        XCTAssertEqual(decoded, settings)

        let plan = try TransformPlan(settings: decoded)
        let input = try RGB64(0.2, 0.2, 0.2)
        let output = try plan.evaluate(input)
        let expected = try gamma.makeTransfer().encodeLegacyToLegal(0.2 / 0.9)
        XCTAssertEqual(output.r, expected, accuracy: 1e-14)
        XCTAssertEqual(output.g, expected, accuracy: 1e-14)
        XCTAssertEqual(output.b, expected, accuracy: 1e-14)
    }

    func testParameterizedGammaSettingsRequireMatchingTransferSlots() throws {
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.2, linearSlope: 1, offset: 0, linearCut: 0.01
        )
        XCTAssertThrowsError(try TransformPlan(settings: TransformSettings(
            inputTransfer: .parameterizedGamma,
            outputTransfer: .linearScene,
            inputSpace: .srgb,
            outputSpace: .srgb,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            outputGamma: gamma
        ))) { error in
            XCTAssertEqual(error as? TransformSettingsError, .missingInputGamma)
        }
        XCTAssertThrowsError(try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .linearScene,
            inputSpace: .srgb,
            outputSpace: .srgb,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            inputGamma: gamma
        ))) { error in
            XCTAssertEqual(error as? TransformSettingsError, .unexpectedInputGamma)
        }
    }

    func testPublishedPiecewiseParametersRoundTrip() throws {
        let transfers = [
            try ParameterizedGammaTransfer(exponent: 2.2, linearSlope: 1,
                                           offset: 0, linearCut: 0.0000001),
            try ParameterizedGammaTransfer(exponent: 1.8, linearSlope: 16,
                                           offset: 0, linearCut: 0,
                                           encodedCut: 0),
            try ParameterizedGammaTransfer(exponent: 3, linearSlope: 24389.0 / 2700.0,
                                           offset: 0.16, linearCut: 216.0 / 24389.0,
                                           encodedCut: 216.0 / 2700.0),
        ]
        for transfer in transfers {
            for value in [0.0, 0.00000005, 0.01, 0.18, 1.0] {
                let encoded = try transfer.encodeLegacyToLegal(value)
                let decoded = try transfer.decodeLegalToLegacy(encoded)
                XCTAssertEqual(decoded, value, accuracy: 1e-14)
            }
        }
    }

    func testOffsetAndSlopeUseExplicitPiecewiseBoundary() throws {
        let transfer = try ParameterizedGammaTransfer(
            exponent: 2.4,
            linearSlope: 4.5,
            offset: 0.1,
            linearCut: 0.02
        )
        XCTAssertEqual(try transfer.encodeLegacyToLegal(0.01), 0.045, accuracy: 1e-15)
        let expected = (1.1 * pow(0.2, 1 / 2.4)) - 0.1
        XCTAssertEqual(try transfer.encodeLegacyToLegal(0.2), expected, accuracy: 1e-15)
        XCTAssertEqual(try transfer.decodeLegalToLegacy(0.045), 0.01, accuracy: 1e-15)
    }

    func testExplicitEncodedCutIsIndependentAndInclusive() throws {
        let transfer = try ParameterizedGammaTransfer(
            exponent: 3,
            linearSlope: 24389.0 / 2700.0,
            offset: 0.16,
            linearCut: 216.0 / 24389.0,
            encodedCut: 0.08
        )
        XCTAssertEqual(transfer.encodedCut, 0.08, accuracy: 0)
        XCTAssertEqual(try transfer.decodeLegalToLegacy(0.08),
                       pow((0.08 + 0.16) / 1.16, 3), accuracy: 1e-15)
        let below = Double(0.08).nextDown
        XCTAssertEqual(try transfer.decodeLegalToLegacy(below),
                       below / (24389.0 / 2700.0), accuracy: 1e-15)
    }

    func testInvalidParametersAndNonFiniteValuesAreRejected() throws {
        XCTAssertThrowsError(try ParameterizedGammaTransfer(exponent: 0, linearSlope: 1,
                                                             offset: 0, linearCut: 0.01))
        XCTAssertThrowsError(try ParameterizedGammaTransfer(exponent: 2.2, linearSlope: 0,
                                                             offset: 0, linearCut: 0.01))
        XCTAssertThrowsError(try ParameterizedGammaTransfer(exponent: 2.2, linearSlope: 1,
                                                             offset: -1, linearCut: 0.01))
        let transfer = try ParameterizedGammaTransfer(exponent: 2.2, linearSlope: 1,
                                                      offset: 0, linearCut: 0.01)
        XCTAssertThrowsError(try transfer.encodeLegacyToLegal(.nan))
        XCTAssertThrowsError(try transfer.decodeLegalToLegacy(.infinity))
    }
}
