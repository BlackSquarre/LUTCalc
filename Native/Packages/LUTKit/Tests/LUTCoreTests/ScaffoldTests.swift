import XCTest
import LUTCore

final class ScaffoldTests: XCTestCase {
    func testEngineVersionIsExplicit() {
        XCTAssertFalse(LUTCoreModule.engineVersion.isEmpty)
    }
}
