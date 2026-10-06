import XCTest
import LUTCatalog

final class NikonLookupBlockContractsTests: XCTestCase {
    func testNikonPictureStyleIOLUTNamesRemainBlockedIndividually() throws {
        let names = [
            "Nikon Standard", "Nikon Neutral", "Nikon Vivid",
            "Nikon Monochrome", "Nikon Portrait", "Nikon Landscape"
        ]
        let blocked = Set(AlgorithmCatalog.blockedLookupRegistrationNames)
        XCTAssertTrue(Set(names).isSubset(of: blocked))

        let catalog = try AlgorithmCatalog.builtIn()
        for name in names {
            XCTAssertNil(catalog.transfer(named: name), name)
            XCTAssertNil(catalog.colorSpace(named: name), name)
            XCTAssertNil(catalog.preset(named: name), name)
        }
    }

    func testRemainingIOLUTNamesStayBlockedWithoutAliasToPublishedTransfers() throws {
        let names = ["DJI Mini 2", "s709", "Rec709 (800%)"]
        let blocked = Set(AlgorithmCatalog.blockedLookupRegistrationNames)
        XCTAssertTrue(Set(names).isSubset(of: blocked))

        let catalog = try AlgorithmCatalog.builtIn()
        for name in names {
            XCTAssertNil(catalog.transfer(named: name), name)
            XCTAssertNil(catalog.colorSpace(named: name), name)
            XCTAssertNil(catalog.preset(named: name), name)
        }
        XCTAssertNotNil(catalog.transfer(named: "Rec.709 (LUTCalc legacy)"))
        XCTAssertNotNil(catalog.transfer(named: "SMPTE 240M"))
    }
}
