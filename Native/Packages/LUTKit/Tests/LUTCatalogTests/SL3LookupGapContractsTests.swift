import XCTest
import LUTCatalog

final class SL3LookupGapContractsTests: XCTestCase {
    func testSL3LookCurvesRemainExplicitlyBlocked() throws {
        let names = [
            "Amira709", "Alexa-X-2", "LC709A", "LC709", "Sony Cine+709",
            "Varicam V709", "REDGamma", "REDGamma2", "REDGamma3", "REDGamma4"
        ]
        let catalog = try AlgorithmCatalog.builtIn()
        for name in names {
            XCTAssertTrue(AlgorithmCatalog.blockedLookupRegistrationNames.contains(name))
            XCTAssertNil(catalog.transfer(named: name), name)
            XCTAssertNil(catalog.colorSpace(named: name), name)
            XCTAssertNil(catalog.preset(named: name), name)
        }
    }
}
