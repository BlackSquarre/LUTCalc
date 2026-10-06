import XCTest
@testable import LUTCore

final class BT2100HLGReferenceOOTFExtendedContractsTests: XCTestCase {
    private struct Sample: Decodable {
        let peakLuminanceNits: String
        let systemGamma: String
        let scene: [String]
        let display: [String]
    }

    private struct Reference: Decodable {
        let algorithm: String
        let precision: Int
        let samples: [Sample]
        let eotfSamples: [EOTFSample]
    }

    private struct EOTFSample: Decodable {
        let peakLuminanceNits: String
        let blackLuminanceNits: String
        let systemGamma: String
        let beta: String
        let encoded: [String]
        let display: [String]
        let inverse: [String]
        let rgbDisplay: [String]
    }

    private func reference() throws -> Reference {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(
            Reference.self,
            from: Data(contentsOf: root.appendingPathComponent(
                "docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf-extended/decimal-reference.json"
            ))
        )
    }

    func testExtendedFormulaUsesExplicitModeAndPublishedKappa() throws {
        XCTAssertThrowsError(try BT2100HLGReferenceOOTF(peakLuminanceNits: 100))
        XCTAssertThrowsError(try BT2100HLGReferenceOOTF(peakLuminanceNits: 10000))

        let low = try BT2100HLGReferenceOOTF(
            peakLuminanceNits: 100,
            gammaMode: .extended
        )
        let high = try BT2100HLGReferenceOOTF(
            peakLuminanceNits: 10000,
            gammaMode: .extended
        )
        XCTAssertEqual(low.gammaMode, .extended)
        XCTAssertEqual(high.gammaMode, .extended)
        XCTAssertEqual(low.systemGamma, 0.8459066308929684, accuracy: 2e-15)
        XCTAssertEqual(high.systemGamma, 1.702315536266557, accuracy: 2e-15)
        XCTAssertEqual(try low.sceneToDisplay(1), 100, accuracy: 2e-13)
        XCTAssertEqual(try high.sceneToDisplay(1), 10000, accuracy: 2e-11)
    }

    func testExtendedFormulaMatchesIndependentNinetyDigitReference() throws {
        let reference = try reference()
        XCTAssertEqual(reference.algorithm, "bt2100.hlg-reference-ootf-extended.v1")
        XCTAssertEqual(reference.precision, 90)
        var maximumError = 0.0
        for sample in reference.samples {
            let peak = try XCTUnwrap(Double(sample.peakLuminanceNits))
            let kernel = try BT2100HLGReferenceOOTF(
                peakLuminanceNits: peak,
                gammaMode: .extended
            )
            XCTAssertEqual(kernel.systemGamma,
                           try XCTUnwrap(Double(sample.systemGamma)), accuracy: 3e-15)
            for (sceneText, displayText) in zip(sample.scene, sample.display) {
                let scene = try XCTUnwrap(Double(sceneText))
                let expected = try XCTUnwrap(Double(displayText))
                let actual = try kernel.sceneToDisplay(scene)
                maximumError = max(maximumError,
                                   abs(actual - expected) / max(1, abs(expected)))
                XCTAssertEqual(try kernel.displayToScene(actual), scene, accuracy: 3e-14)
            }
        }
        XCTAssertLessThanOrEqual(maximumError, 3e-14)
        print("BT.2100 HLG extended gamma Decimal maximum scaled error: \(maximumError)")
    }

    func testExtendedGammaEOTFMatchesIndependentNinetyDigitReference() throws {
        let reference = try reference()
        var maximumError = 0.0
        for sample in reference.eotfSamples {
            let peak = try XCTUnwrap(Double(sample.peakLuminanceNits))
            let black = try XCTUnwrap(Double(sample.blackLuminanceNits))
            let kernel = try BT2100HLGReferenceOOTF(
                peakLuminanceNits: peak,
                gammaMode: .extended
            )
            XCTAssertEqual(kernel.systemGamma,
                           try XCTUnwrap(Double(sample.systemGamma)), accuracy: 3e-15)
            XCTAssertEqual(try kernel.blackLevelLift(blackLuminanceNits: black),
                           try XCTUnwrap(Double(sample.beta)), accuracy: 3e-15)

            for (encodedText, displayText) in zip(sample.encoded, sample.display) {
                let encoded = try XCTUnwrap(Double(encodedText))
                let expected = try XCTUnwrap(Double(displayText))
                let actual = try kernel.encodedHLGToDisplay(
                    encoded, blackLuminanceNits: black
                )
                maximumError = max(maximumError,
                                   abs(actual - expected) / max(1, abs(expected)))
                if expected > 0 {
                    XCTAssertEqual(try kernel.displayToEncodedHLG(
                        expected, blackLuminanceNits: black
                    ), encoded, accuracy: 5e-13)
                }
            }

            let encodedRGB = try RGB64(0.5, 0.75, 0.25)
            let expectedRGB = try RGB64(
                try XCTUnwrap(Double(sample.rgbDisplay[0])),
                try XCTUnwrap(Double(sample.rgbDisplay[1])),
                try XCTUnwrap(Double(sample.rgbDisplay[2]))
            )
            let actualRGB = try kernel.encodedHLGRGBToDisplay(
                encodedRGB, blackLuminanceNits: black
            )
            for channel in 0..<3 {
                maximumError = max(maximumError,
                                   abs(actualRGB[channel] - expectedRGB[channel]) /
                                   max(1, abs(expectedRGB[channel])))
            }
            let recovered = try kernel.displayRGBToEncodedHLG(
                actualRGB, blackLuminanceNits: black
            )
            XCTAssertEqual(recovered.r, encodedRGB.r, accuracy: 8e-13)
            XCTAssertEqual(recovered.g, encodedRGB.g, accuracy: 8e-13)
            XCTAssertEqual(recovered.b, encodedRGB.b, accuracy: 8e-13)
        }
        XCTAssertLessThanOrEqual(maximumError, 5e-13)
        print("BT.2100 HLG extended EOTF Decimal maximum scaled error: \(maximumError)")
    }

    func testExtendedModeRejectsNonPositiveAndNonFinitePeaks() throws {
        for peak in [0.0, -1.0, .nan, .infinity, -.infinity] {
            XCTAssertThrowsError(try BT2100HLGReferenceOOTF(
                peakLuminanceNits: peak,
                gammaMode: .extended
            ))
        }
    }
}
