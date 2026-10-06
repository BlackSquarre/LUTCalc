import Foundation
import XCTest
@testable import LUTCore

final class BT2100HLGReferenceOOTFContractsTests: XCTestCase {
    private struct Sample: Decodable {
        let input: [String]
        let output: [String]
    }

    private struct Reference: Decodable {
        let algorithm: String
        let precision: Int
        let peakLuminanceNits: String
        let systemGamma: String
        let scalar: [Sample]
        let rgb: [Sample]
    }

    private func reference() throws -> Reference {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(
            Reference.self,
            from: Data(contentsOf: root.appendingPathComponent(
                "docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf/decimal-reference.json"
            ))
        )
    }

    func testPublishedFormulaAndNeutralWhite() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        XCTAssertEqual(ootf.systemGamma, 1.2, accuracy: 2e-15)
        XCTAssertEqual(try ootf.sceneToDisplay(1), 1000, accuracy: 2e-13)
        XCTAssertEqual(try ootf.sceneToDisplay(0.18), 127.74002773725992, accuracy: 2e-12)
        XCTAssertEqual(try ootf.displayToScene(1000), 1, accuracy: 2e-15)
        XCTAssertEqual(try ootf.displayToScene(127.74002773725992), 0.18, accuracy: 2e-14)
    }

    func testRGBLumaCouplingAndNegativeChromaticComponent() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        let input = try RGB64(0.8, -0.1, 0.4)
        let output = try ootf.sceneRGBToDisplay(input)
        let recovered = try ootf.displayRGBToScene(output)
        XCTAssertTrue(output.r.isFinite && output.g.isFinite && output.b.isFinite)
        XCTAssertEqual(recovered.r, input.r, accuracy: 2e-14)
        XCTAssertEqual(recovered.g, input.g, accuracy: 2e-14)
        XCTAssertEqual(recovered.b, input.b, accuracy: 2e-14)
        XCTAssertEqual(try ootf.sceneRGBToDisplay(RGB64(1, 1, 1)).r, 1000, accuracy: 2e-13)
    }

    func testDomainAndNonUniqueZeroLumaAreRejected() throws {
        XCTAssertThrowsError(try BT2100HLGReferenceOOTF(peakLuminanceNits: 399.999))
        XCTAssertThrowsError(try BT2100HLGReferenceOOTF(peakLuminanceNits: 2000.001))
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        XCTAssertThrowsError(try ootf.sceneToDisplay(-0.1))
        XCTAssertThrowsError(try ootf.displayToScene(-0.1))
        XCTAssertThrowsError(try ootf.displayRGBToScene(RGB64(1, -0.2627 / 0.6780, 0)))
    }

    func testReferenceSettingsConstructPlanAndNormalizeBeforeHLGOETF() throws {
        let ootfSettings = HLGOOTFSettings(
            inputPeakNits: 1000,
            outputPeakNits: 1000,
            inputBlackNits: 0,
            outputBlackNits: 0,
            scale: .nits,
            bbcInput: false,
            bbcOutput: false,
            algorithm: .bt2100HLGReferenceV1
        )
        let settings = TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .rec2100HLG,
            inputSpace: .rec2020,
            outputSpace: .rec2020,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            hlgOOTF: ootfSettings
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertTrue(plan.planVersion.contains(ootfSettings.algorithm.rawValue))

        let input = try RGB64(0.18, 0.18, 0.18)
        let trace = try plan.trace(input)
        let displayStage = try XCTUnwrap(trace.stages.first { $0.id == 130 })
        let referenceKernel = try ootfSettings.makeReferenceKernel()
        let expectedDisplay = try referenceKernel.sceneRGBToDisplay(input)
        XCTAssertEqual(displayStage.output, expectedDisplay)

        let expectedEncoded = try HLGTransfer.encodeSceneToData(expectedDisplay.r / 1000)
        XCTAssertEqual(trace.output.r, expectedEncoded, accuracy: 2e-14)
        XCTAssertEqual(trace.output.g, expectedEncoded, accuracy: 2e-14)
        XCTAssertEqual(trace.output.b, expectedEncoded, accuracy: 2e-14)
    }

    func testReferenceSettingsRejectNormalizedScaleAndLegacyParameters() throws {
        let normalized = HLGOOTFSettings(
            scale: .normalizedBy1000,
            algorithm: .bt2100HLGReferenceV1
        )
        XCTAssertThrowsError(try normalized.makeReferenceKernel()) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        let normalizedSettings = TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .rec2100HLG,
            inputSpace: .rec2020,
            outputSpace: .rec2020,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            hlgOOTF: normalized
        )
        XCTAssertThrowsError(try TransformPlan(settings: normalizedSettings)) {
            XCTAssertEqual($0 as? TransformSettingsError, .invalidHLGOOTFScale)
        }

        let invalidConfigurations: [HLGOOTFSettings] = [
            HLGOOTFSettings(inputPeakNits: 800, outputPeakNits: 1000,
                            algorithm: .bt2100HLGReferenceV1),
            HLGOOTFSettings(inputBlackNits: 1,
                            algorithm: .bt2100HLGReferenceV1),
            HLGOOTFSettings(outputBlackNits: 1,
                            algorithm: .bt2100HLGReferenceV1),
            HLGOOTFSettings(bbcInput: true,
                            algorithm: .bt2100HLGReferenceV1),
            HLGOOTFSettings(bbcOutput: true,
                            algorithm: .bt2100HLGReferenceV1),
        ]
        for configuration in invalidConfigurations {
            XCTAssertThrowsError(try configuration.makeReferenceKernel())
        }
    }

    func testNinetyDigitDecimalReference() throws {
        let reference = try reference()
        XCTAssertEqual(reference.algorithm, "bt2100.hlg-reference-ootf.v1")
        XCTAssertEqual(reference.precision, 90)
        let peak = try XCTUnwrap(Double(reference.peakLuminanceNits))
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: peak)
        XCTAssertEqual(ootf.systemGamma, try XCTUnwrap(Double(reference.systemGamma)), accuracy: 2e-15)

        var scalarErrors: [Double] = []
        for sample in reference.scalar {
            let input = try XCTUnwrap(Double(sample.input[0]))
            let expected = try XCTUnwrap(Double(sample.output[0]))
            scalarErrors.append(abs(try ootf.sceneToDisplay(input) - expected) / max(1, abs(expected)))
        }
        var rgbErrors: [Double] = []
        for sample in reference.rgb {
            let input = try RGB64(
                try XCTUnwrap(Double(sample.input[0])),
                try XCTUnwrap(Double(sample.input[1])),
                try XCTUnwrap(Double(sample.input[2]))
            )
            let expected = [
                try XCTUnwrap(Double(sample.output[0])),
                try XCTUnwrap(Double(sample.output[1])),
                try XCTUnwrap(Double(sample.output[2])),
            ]
            let actual = try ootf.sceneRGBToDisplay(input)
            for index in 0..<3 {
                rgbErrors.append(abs(actual[index] - expected[index]) / max(1, abs(expected[index])))
            }
        }
        XCTAssertLessThanOrEqual(scalarErrors.max() ?? .infinity, 3e-14)
        XCTAssertLessThanOrEqual(rgbErrors.max() ?? .infinity, 3e-14)
        print("BT.2100 HLG reference OOTF Decimal: scalarMax=\(scalarErrors.max() ?? .infinity), rgbMax=\(rgbErrors.max() ?? .infinity)")
    }
}
