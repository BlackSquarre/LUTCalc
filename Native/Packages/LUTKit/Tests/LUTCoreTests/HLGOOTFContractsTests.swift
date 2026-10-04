import XCTest
@testable import LUTCore

final class HLGOOTFContractsTests: XCTestCase {
    func testPublishedDefaultNitsScalarAndInverse() throws {
        let ootf = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 0, outputBlackNits: 0,
                               scale: .nits)
        XCTAssertEqual(try ootf.sceneToDisplay(0.18, side: .output), 6.476039825649833, accuracy: 2e-14)
        XCTAssertEqual(try ootf.sceneToDisplay(1, side: .output), 50.69702849110049, accuracy: 2e-14)
        XCTAssertEqual(try ootf.displayToScene(6.476039825649833, side: .output), 0.18, accuracy: 2e-14)
        XCTAssertEqual(try ootf.displayToScene(0, side: .output), 0, accuracy: 0)
        XCTAssertEqual(try ootf.sceneToDisplay(12, side: .output), 1000, accuracy: 0)
    }

    func testNormalizedScaleAndBlackLevel() throws {
        let ootf = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 10, outputBlackNits: 10,
                               scale: .normalizedBy1000)
        XCTAssertEqual(try ootf.sceneToDisplay(0, side: .output), 0.01, accuracy: 2e-14)
        XCTAssertEqual(try ootf.sceneToDisplay(0.18, side: .output), 0.016411279427393335, accuracy: 2e-14)
        XCTAssertEqual(try ootf.displayToScene(0.016411279427393335, side: .output), 0.18, accuracy: 2e-14)
    }

    func testDisplayRGBInverseReturnsSceneBlackAtUniformOutputBlack() throws {
        let ootf = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 0, outputBlackNits: 10,
                               scale: .nits)
        let scene = try ootf.displayRGBToScene(RGB64(10, 10, 10), side: .output)
        XCTAssertEqual(scene.r, 0, accuracy: 0)
        XCTAssertEqual(scene.g, 0, accuracy: 0)
        XCTAssertEqual(scene.b, 0, accuracy: 0)
        XCTAssertThrowsError(try ootf.displayRGBToScene(RGB64(9.9, 10, 10), side: .output)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
    }

    func testDisplayRGBInverseRejectsPeakClippedNonUniqueValues() throws {
        let ootf = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 0, outputBlackNits: 0)
        let singleChannelClip = try ootf.sceneRGBToDisplay(RGB64(100, 3, 0.5), side: .output)
        XCTAssertEqual(singleChannelClip.r, 1000, accuracy: 0)
        XCTAssertLessThan(singleChannelClip.g, 1000)
        XCTAssertLessThan(singleChannelClip.b, 1000)
        XCTAssertThrowsError(try ootf.displayRGBToScene(singleChannelClip, side: .output)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }

        let neutralPeak = try ootf.sceneRGBToDisplay(RGB64(12, 12, 12), side: .output)
        XCTAssertEqual(neutralPeak, try RGB64(1000, 1000, 1000))
        XCTAssertThrowsError(try ootf.displayRGBToScene(neutralPeak, side: .output)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
    }

    func testDisplayScalarInverseRejectsPeakClippedNonUniqueValue() throws {
        let nits = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 0, outputBlackNits: 0, scale: .nits)
        XCTAssertEqual(try nits.sceneToDisplay(12, side: .output), 1000, accuracy: 0)
        XCTAssertThrowsError(try nits.displayToScene(1000, side: .output)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }

        let normalized = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                                     inputBlackNits: 0, outputBlackNits: 0,
                                     scale: .normalizedBy1000)
        XCTAssertEqual(try normalized.sceneToDisplay(12, side: .output), 1, accuracy: 0)
        XCTAssertThrowsError(try normalized.displayToScene(1, side: .output)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
    }

    func testRGBBlackEndpointsAcrossSidesScalesAndSystemGamma() throws {
        for peak in [100.0, 400, 1000, 4000] {
            for black in [0.0, 0.3, 10] {
                for scale in [HLGOOTF.Scale.nits, .normalizedBy1000] {
                    let kernel = try HLGOOTF(inputPeakNits: peak, outputPeakNits: peak,
                                             inputBlackNits: black, outputBlackNits: black,
                                             scale: scale, bbcInput: true)
                    let floor = black * (scale == .nits ? 1 : 0.001)
                    for side in [HLGOOTF.Side.input, .output] {
                        let encoded = try kernel.sceneRGBToDisplay(RGB64(0, 0, 0), side: side)
                        let decoded = try kernel.displayRGBToScene(RGB64(floor, floor, floor), side: side)
                        for channel in 0..<3 {
                            XCTAssertEqual(encoded[channel], floor, accuracy: 0)
                            XCTAssertEqual(decoded[channel], 0, accuracy: 0)
                        }
                    }
                }
            }
        }
    }

    func testBBCCoefficientsAndRGBLuminanceCoupling() throws {
        let ootf = try HLGOOTF(inputPeakNits: 400, outputPeakNits: 400,
                               inputBlackNits: 0, outputBlackNits: 0,
                               scale: .nits, bbcInput: true, bbcOutput: true)
        XCTAssertEqual(try ootf.sceneToDisplay(0.18, side: .output), 15.256460622889294, accuracy: 2e-14)
        let rgb = try ootf.sceneRGBToDisplay(RGB64(0.18, 0.36, 0.09), side: .output)
        XCTAssertTrue(rgb.r.isFinite && rgb.g.isFinite && rgb.b.isFinite)
        let roundTrip = try ootf.displayRGBToScene(rgb, side: .output)
        XCTAssertEqual(roundTrip.r, 0.18, accuracy: 2e-12)
        XCTAssertEqual(roundTrip.g, 0.36, accuracy: 2e-12)
        XCTAssertEqual(roundTrip.b, 0.09, accuracy: 2e-12)
    }

    func testPeakAndFiniteDomainsAreStrict() throws {
        XCTAssertThrowsError(try HLGOOTF(inputPeakNits: 0, outputPeakNits: 1000,
                                         inputBlackNits: 0, outputBlackNits: 0))
        let ootf = try HLGOOTF(inputPeakNits: 1000, outputPeakNits: 1000,
                               inputBlackNits: 0, outputBlackNits: 0)
        for x in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try ootf.sceneToDisplay(x, side: .output))
            XCTAssertThrowsError(try ootf.displayToScene(x, side: .output))
        }
        XCTAssertThrowsError(try ootf.displayToScene(-0.1, side: .output))
        XCTAssertThrowsError(try ootf.displayToScene(1000.1, side: .output))
    }

    func testSettingsRoundTripAndPlanTrace() throws {
        let settings = HLGOOTFSettings(inputPeakNits: 1000, outputPeakNits: 1000,
                                       inputBlackNits: 0, outputBlackNits: 0,
                                       scale: .normalizedBy1000, bbcOutput: true)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(HLGOOTFSettings.self, from: data), settings)
        let planSettings = TransformSettings(inputTransfer: .linearScene,
                                             outputTransfer: .rec2100HLG,
                                             inputSpace: .rec2020, outputSpace: .rec2020,
                                             inputRange: .data, outputRange: .data,
                                             exposureStops: 0, hlgOOTF: settings)
        let plan = try TransformPlan(settings: planSettings)
        let trace = try plan.trace(RGB64(0.18, 0.18, 0.18))
        XCTAssertEqual(trace.stages.map(\.id), [1, 2, 3, 4, 10, 130, 13, 19])
        let ootf = try XCTUnwrap(trace.stages.first { $0.id == 130 })
        XCTAssertEqual(ootf.output.r, 0.02248224488944945, accuracy: 2e-14)
        XCTAssertTrue(trace.output.r.isFinite)
        XCTAssertTrue(plan.planVersion.contains(settings.algorithm.rawValue))
    }

    func testPlanNormalizesNitsBeforeHLGOETFAndRejectsWrongTransfer() throws {
        let nits = HLGOOTFSettings(scale: .nits)
        let wrongTransfer = TransformSettings(inputTransfer: .linearScene,
                                              outputTransfer: .rec2100PQ,
                                              inputSpace: .rec2020, outputSpace: .rec2020,
                                              inputRange: .data, outputRange: .data,
                                              exposureStops: 0, hlgOOTF: nits)
        XCTAssertThrowsError(try TransformPlan(settings: wrongTransfer)) {
            XCTAssertEqual($0 as? TransformSettingsError, .invalidHLGOOTFTransfer)
        }
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .rec2100HLG,
                                         inputSpace: .rec2020, outputSpace: .rec2020,
                                         inputRange: .data, outputRange: .data,
                                         exposureStops: 0, hlgOOTF: nits)
        let plan = try TransformPlan(settings: settings)
        let trace = try plan.trace(RGB64(0.18, 0.18, 0.18))
        let display = try XCTUnwrap(trace.stages.first { $0.id == 130 })
        XCTAssertEqual(display.output.r, 6.476039825649833, accuracy: 2e-14)
        XCTAssertEqual(trace.output.r,
                       try HLGTransfer.encodeSceneToData(6.476039825649833 / 1000),
                       accuracy: 2e-14)
    }

    func testNitsNormalizationAlsoCoversPostGammaSecondaryScene() throws {
        let common = TransformSettings(inputTransfer: .linearScene,
                                       outputTransfer: .rec2100HLG,
                                       inputSpace: .rec2020, outputSpace: .rec2020,
                                       inputRange: .data, outputRange: .data,
                                       exposureStops: 0,
                                       gamutLimiter: try GamutLimiterSettings(
                                           mode: .postGamma, postLevel: 0.85,
                                           secondarySpace: .srgb, protectBoth: true))
        let nits = try TransformPlan(settings: common.withHLGOOTF(HLGOOTFSettings(scale: .nits)))
        let normalized = try TransformPlan(settings: common.withHLGOOTF(HLGOOTFSettings(scale: .normalizedBy1000)))
        let input = try RGB64(0.82, 0.17, 0.04)
        let nitsTrace = try nits.trace(input)
        let normalizedTrace = try normalized.trace(input)
        XCTAssertNotNil(nitsTrace.stages.first { $0.id == 17 })
        XCTAssertNotNil(normalizedTrace.stages.first { $0.id == 17 })
        for channel in 0..<3 {
            XCTAssertEqual(nitsTrace.output[channel], normalizedTrace.output[channel], accuracy: 2e-14)
        }
    }

    func testDerivedSettingsPreserveHLGOOTFUntilOutputTransferChanges() throws {
        let ootf = HLGOOTFSettings(outputPeakNits: 600, outputBlackNits: 2)
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .rec2100HLG,
                                         inputSpace: .rec2020, outputSpace: .rec2020,
                                         inputRange: .data, outputRange: .data,
                                         exposureStops: 0, hlgOOTF: ootf)

        let derived: [TransformSettings] = [
            settings.withInputRange(.video),
            settings.withOutputRange(.video),
            settings.withRangeBitDepth(12),
            settings.withAdaptation(.bradford),
            settings.withCameraExposure(nil),
            settings.withExposureStops(1),
            settings.withInput(transfer: .linearScene, space: .rec2020),
            settings.withOutput(transfer: .rec2100HLG, space: .rec2020),
            settings.withASCCDL(nil),
            settings.withSDRSaturation(nil),
            settings.withMultitone(nil),
            settings.withBlackGamma(nil),
            settings.withBlackHighlight(nil),
            settings.withKnee(nil),
            settings.withHighlightGamut(nil),
            settings.withGamutLimiter(nil),
            settings.withOutputCodeUnits(.completeV2),
            settings.withDisplayConversion(nil),
            settings.withFalseColour(nil),
            settings.withFinalOutput(nil),
            settings.withInputLogC(nil),
            settings.withOutputLogC(nil),
            settings.withHLGOOTF(ootf)
        ]
        XCTAssertTrue(derived.allSatisfy { $0.hlgOOTF == ootf })
        XCTAssertNil(settings.withOutput(transfer: .linearScene, space: .rec2020).hlgOOTF)
    }
}
