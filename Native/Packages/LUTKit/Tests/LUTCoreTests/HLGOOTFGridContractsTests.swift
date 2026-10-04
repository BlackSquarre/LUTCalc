import XCTest
@testable import LUTCore

/// Independent BT.2100/LUTCalc HLG OOTF reference for the already supported
/// scalar/RGB display-domain subset. The literals are intentionally kept out
/// of the production implementation so this test does not call its helpers.
final class HLGOOTFGridContractsTests: XCTestCase {
    private let luma = (r: 0.2627, g: 0.6780, b: 0.0593)
    private let bbc = 2.821251498
    private let tolerance = 2e-12

    private func parameters(peak: Double, black: Double) -> (gamma: Double, a: Double) {
        let gamma = 1.2 + 0.42 * log10(peak / 1000.0)
        return (gamma, (peak - black) / pow(12.0, gamma))
    }

    private func independentRGB(_ scene: RGB64, peak: Double, black: Double,
                                scale: Double, useBBC: Bool) throws -> RGB64 {
        let p = parameters(peak: peak, black: black)
        let multiplier = useBBC ? bbc : 1.0
        let r = max(0, scene.r) * multiplier
        let g = max(0, scene.g) * multiplier
        let b = max(0, scene.b) * multiplier
        let y = luma.r * r + luma.g * g + luma.b * b
        if r == 0 && g == 0 && b == 0 {
            return try RGB64(black * scale, black * scale, black * scale)
        }
        let factor = p.a * pow(y, p.gamma - 1.0)
        return try RGB64(
            min(peak * scale, (factor * r + black) * scale),
            min(peak * scale, (factor * g + black) * scale),
            min(peak * scale, (factor * b + black) * scale))
    }

    private func independentInverse(_ display: RGB64, peak: Double, black: Double,
                                    scale: Double, useBBC: Bool) throws -> RGB64 {
        let p = parameters(peak: peak, black: black)
        let multiplier = useBBC ? bbc : 1.0
        let displayBlack = black * scale
        if display.r == displayBlack && display.g == displayBlack && display.b == displayBlack {
            return try RGB64(0, 0, 0)
        }
        let y = luma.r * display.r + luma.g * display.g + luma.b * display.b
        let luminance = pow(max(0, (y / scale) - black) / p.a,
                            (1.0 - p.gamma) / p.gamma) / (p.a * multiplier)
        return try RGB64(
            luminance * ((display.r / scale) - black),
            luminance * ((display.g / scale) - black),
            luminance * ((display.b / scale) - black))
    }

    func testIndependentComplete33And65RGBGrids() throws {
        let peak = 1000.0
        let black = 10.0
        let scale = 0.001
        let kernel = try HLGOOTF(inputPeakNits: peak, outputPeakNits: peak,
                                 inputBlackNits: black, outputBlackNits: black,
                                 scale: .normalizedBy1000, bbcOutput: true)
        var maximumForward = 0.0
        var maximumInverse = 0.0
        var count = 0
        for size in [33, 65] {
            for z in 0..<size {
                for y in 0..<size {
                    for x in 0..<size {
                        // Keep the full requested grid while staying below
                        // the peak clip so the inverse has a unique target.
                        let point = try RGB64(
                            0.4 * Double(x) / Double(size - 1),
                            0.4 * Double(y) / Double(size - 1),
                            0.4 * Double(z) / Double(size - 1))
                        let expected = try independentRGB(point, peak: peak, black: black,
                                                           scale: scale, useBBC: true)
                        let actual = try kernel.sceneRGBToDisplay(point, side: .output)
                        for channel in 0..<3 {
                            let error = abs(actual[channel] - expected[channel]) /
                                max(1.0, abs(expected[channel]))
                            maximumForward = max(maximumForward, error)
                        }
                        let recovered = try kernel.displayRGBToScene(actual, side: .output)
                        let inverseExpected = try independentInverse(actual, peak: peak,
                                                                      black: black,
                                                                      scale: scale, useBBC: true)
                        for channel in 0..<3 {
                            let inverseError = abs(recovered[channel] - inverseExpected[channel]) /
                                max(1.0, abs(inverseExpected[channel]))
                            maximumInverse = max(maximumInverse, inverseError)
                        }
                        count += 3
                    }
                }
            }
        }
        XCTAssertEqual(count, 3 * (33 * 33 * 33 + 65 * 65 * 65))
        XCTAssertLessThanOrEqual(maximumForward, tolerance)
        XCTAssertLessThanOrEqual(maximumInverse, tolerance)
        print("HLG OOTF independent RGB 33³/65³: channels=\(count), forwardMax=\(maximumForward), inverseMax=\(maximumInverse)")
    }

    func testIndependentScalarBranchesAndPeakClip() throws {
        let kernel = try HLGOOTF(inputPeakNits: 400, outputPeakNits: 1000,
                                 inputBlackNits: 0.3, outputBlackNits: 10,
                                 scale: .nits, bbcOutput: true)
        let output = try kernel.sceneToDisplay(0.18, side: .output)
        let p = parameters(peak: 1000, black: 10)
        let expected = (p.a * pow(0.18 * bbc, p.gamma) + 10)
        XCTAssertEqual(output, expected, accuracy: 2e-12)
        XCTAssertEqual(try kernel.sceneToDisplay(12, side: .output), 1000, accuracy: 0)
        XCTAssertEqual(try kernel.sceneToDisplay(-1, side: .output), 10, accuracy: 0)
    }
}
