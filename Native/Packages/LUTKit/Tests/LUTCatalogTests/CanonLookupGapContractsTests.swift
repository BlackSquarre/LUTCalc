import XCTest
import LUTCatalog
import LUTCore

final class CanonLookupGapContractsTests: XCTestCase {
    func testCanonLookupCurvesRemainExplicitlyBlocked() throws {
        let names = [
            "EOS Standard", "EOS Standard (Legal)",
            "Canon Normal 1", "Canon Normal 2", "Canon Normal 3", "Canon Normal 4",
            "Canon WideDR"
        ]
        let catalog = try AlgorithmCatalog.builtIn()
        for name in names {
            XCTAssertTrue(AlgorithmCatalog.blockedLookupRegistrationNames.contains(name))
            XCTAssertNil(catalog.transfer(named: name), name)
            XCTAssertNil(catalog.colorSpace(named: name), name)
            XCTAssertNil(catalog.preset(named: name), name)
        }
    }

    func testCanonLookupNamesCannotAliasPublishedOrAnalyticCanonCurves() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let published: Set<TransferID> = [
            .rec709LUTCalcLegacy, .bt1886, .canonCLog2, .canonCLog3,
            .canonCLogLUTCalcLegacy
        ]
        for name in [
            "EOS Standard", "EOS Standard (Legal)", "Canon Normal 1", "Canon Normal 2",
            "Canon Normal 3", "Canon Normal 4", "Canon WideDR"
        ] {
            XCTAssertNil(catalog.transfer(named: name))
        }
        XCTAssertEqual(published, [
            catalog.transfer(named: "Rec.709 (LUTCalc legacy)")!.id,
            catalog.transfer(named: "BT.1886")!.id,
            catalog.transfer(named: "Canon C-Log2")!.id,
            catalog.transfer(named: "Canon C-Log3")!.id,
            catalog.transfer(named: "Canon C-Log (LUTCalc legacy)")!.id
        ])
    }
}
