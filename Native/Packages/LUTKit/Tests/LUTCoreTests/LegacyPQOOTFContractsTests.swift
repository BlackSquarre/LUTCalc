import XCTest
@testable import LUTCore

final class LegacyPQOOTFContractsTests: XCTestCase {
    func testLegacyForwardAndInverseUseTheFrozenPiecewiseFormula() throws {
        let ootf = try LegacyPQOOTF(inputPeakNits: 1_000,
                                    outputPeakNits: 1_000,
                                    scale: .nits)

        XCTAssertEqual(try ootf.forward(0.18, side: .output),
                       5.704834098099198,
                       accuracy: 2e-15)
        XCTAssertEqual(try ootf.forward(100, side: .output),
                       1_000,
                       accuracy: 1e-12)
        XCTAssertEqual(try ootf.inverse(5.704834098099198, side: .output),
                       0.18,
                       accuracy: 2e-14)
        XCTAssertEqual(try ootf.inverse(0, side: .output), 0, accuracy: 0)
        XCTAssertEqual(try ootf.forward(-1, side: .output), 0, accuracy: 0)
    }

    func testLegacyNormalizedScaleAndDataWrapperPreserveHistoricalUnits() throws {
        let ootf = try LegacyPQOOTF(inputPeakNits: 1_000,
                                    outputPeakNits: 1_000,
                                    scale: .normalized)
        let normalized = try ootf.forward(0.18, side: .output)
        XCTAssertEqual(normalized, 0.0005704834098099198, accuracy: 2e-16)
        XCTAssertEqual(try ootf.inverse(normalized, side: .output), 0.18, accuracy: 2e-14)

        let data = try ootf.forwardData(0.18, side: .output)
        XCTAssertEqual(data, normalized * 0.85630498533724 + 0.06256109481916,
                       accuracy: 2e-16)
        XCTAssertEqual(try ootf.inverseData(data, side: .output), 0.18, accuracy: 2e-14)
    }

    func testLegacyThresholdDiscontinuityIsExplicitAndNotSmoothed() throws {
        let ootf = try LegacyPQOOTF(inputPeakNits: 1_000,
                                    outputPeakNits: 1_000,
                                    scale: .nits)
        let lowerInput = 100.0 * LegacyPQOOTF.knee.nextDown
        let thresholdInput = 100.0 * LegacyPQOOTF.knee
        let upperInput = 100.0 * LegacyPQOOTF.knee.nextUp
        let lower = try ootf.forward(lowerInput, side: .output)
        let threshold = try ootf.forward(thresholdInput, side: .output)
        let upper = try ootf.forward(upperInput, side: .output)
        let lowerExpected = 100.0 * pow(LegacyPQOOTF.toeSlope * LegacyPQOOTF.knee.nextDown, 2.4)
        let thresholdExpected = 100.0 * pow(LegacyPQOOTF.toeSlope * LegacyPQOOTF.knee, 2.4)
        let upperExpected = 100.0 * pow(
            LegacyPQOOTF.logGain * pow(LegacyPQOOTF.logScale * LegacyPQOOTF.knee.nextUp, 0.45) - LegacyPQOOTF.logOffset,
            2.4)
        XCTAssertEqual(lower, lowerExpected, accuracy: 2e-14)
        XCTAssertEqual(threshold, thresholdExpected, accuracy: 2e-14)
        XCTAssertEqual(upper, upperExpected, accuracy: 2e-14)
        XCTAssertLessThan(lower, threshold)
        XCTAssertGreaterThan(upper - threshold, 1.7e-3)
    }

    func testLegacyRejectsNonFiniteArgumentsAndInvalidPeaks() throws {
        XCTAssertThrowsError(try LegacyPQOOTF(inputPeakNits: 0,
                                              outputPeakNits: 1_000,
                                              scale: .nits))
        let ootf = try LegacyPQOOTF(inputPeakNits: 1_000,
                                    outputPeakNits: 1_000,
                                    scale: .nits)
        XCTAssertThrowsError(try ootf.forward(.nan, side: .output))
        XCTAssertThrowsError(try ootf.inverse(.infinity, side: .output))
        XCTAssertThrowsError(try ootf.forwardData(.infinity, side: .output))
        XCTAssertThrowsError(try ootf.inverseData(.nan, side: .output))
    }
}
