import XCTest
@testable import LUTCore
import LUTCatalog

final class REDLogFilmContractsTests: XCTestCase {
    func testPublishedAndLegacyRedLogFilmUseExplicitIdentities() throws {
        XCTAssertEqual(try REDLogFilmTransfer.encodeSceneToData(0.18),
                       try CineonTransfer.encodeSceneToData(0.18), accuracy: 2e-15)
        XCTAssertEqual(try REDLogFilmTransfer.encodeLegacyToData(0.2),
                       try CineonTransfer.encodeLegacyToData(0.2), accuracy: 2e-15)
        XCTAssertThrowsError(try REDLogFilmTransfer.encodeSceneToData(-0.1))
        XCTAssertTrue(try REDLogFilmTransfer.encodeLegacyToData(-0.1).isFinite)
    }

    func testRedPlanAndProjectCatalogRoundTrip() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "REDLogFilm")?.id, .redLogFilm)
        XCTAssertEqual(catalog.colorSpace(named: "REDWideGamutRGB")?.id, .redWideGamutRGB)
        let settings = TransformSettings(inputTransfer: .redLogFilm, outputTransfer: .linearScene,
            inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let plan = try TransformPlan(settings: settings)
        XCTAssertTrue(plan.planVersion.contains("red.logfilm.v1"))
        XCTAssertEqual(try plan.evaluate(RGB64(try REDLogFilmTransfer.encodeSceneToData(0.18),
                                               try REDLogFilmTransfer.encodeSceneToData(0.18),
                                               try REDLogFilmTransfer.encodeSceneToData(0.18))).r,
                       0.18, accuracy: 2e-14)
    }

    func testPlanIdentityIncludesBothColorSpaces() throws {
        for transfer in [TransferID.redLogFilm, .redLogFilmLUTCalcLegacy] {
            func version(input: ColorSpaceID, output: ColorSpaceID) throws -> String {
                try TransformPlan(settings: TransformSettings(
                    inputTransfer: transfer, outputTransfer: .linearScene,
                    inputSpace: input, outputSpace: output,
                    inputRange: .data, outputRange: .data, exposureStops: 0
                )).planVersion
            }
            let baseline = try version(input: .redWideGamutRGB, output: .redWideGamutRGB)
            XCTAssertNotEqual(baseline, try version(input: .rec2020, output: .redWideGamutRGB))
            XCTAssertNotEqual(baseline, try version(input: .redWideGamutRGB, output: .displayP3))
            XCTAssertTrue(baseline.contains("inSpace:red.wide-gamut-rgb.v1"))
            XCTAssertTrue(baseline.contains("outSpace:red.wide-gamut-rgb.v1"))
        }
    }
}
