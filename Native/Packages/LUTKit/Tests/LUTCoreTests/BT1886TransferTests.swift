import XCTest
@testable import LUTCore

final class BT1886TransferTests: XCTestCase {
    func testDefaultBlackAndWhiteLevelsMatchGammaTwoPointFour() throws {
        XCTAssertEqual(try BT1886Transfer.encodeDisplayToLuminance(0), 0, accuracy: 1e-15)
        XCTAssertEqual(try BT1886Transfer.encodeDisplayToLuminance(0.5), pow(0.5, 2.4), accuracy: 1e-15)
        XCTAssertEqual(try BT1886Transfer.encodeDisplayToLuminance(1), 1, accuracy: 1e-15)
        XCTAssertEqual(try BT1886Transfer.decodeLuminanceToDisplay(pow(0.5, 2.4)), 0.5, accuracy: 1e-14)
    }

    func testNonZeroBlackLevelUsesBT1886EndpointEquation() throws {
        let transfer = try BT1886Transfer(blackLevel: 0.01, whiteLevel: 1, gamma: 2.4)
        XCTAssertEqual(try transfer.encodeDisplayToLuminance(0), 0.01, accuracy: 1e-14)
        XCTAssertEqual(try transfer.encodeDisplayToLuminance(1), 1, accuracy: 1e-14)
        let mid = try transfer.encodeDisplayToLuminance(0.5)
        XCTAssertEqual(try transfer.decodeLuminanceToDisplay(mid), 0.5, accuracy: 1e-14)
    }

    func testRejectsInvalidInputsAndPreservesSignedZeroPolicy() throws {
        XCTAssertThrowsError(try BT1886Transfer(blackLevel: -0.1, whiteLevel: 1, gamma: 2.4))
        XCTAssertThrowsError(try BT1886Transfer(blackLevel: 1, whiteLevel: 1, gamma: 2.4))
        XCTAssertThrowsError(try BT1886Transfer(blackLevel: 0, whiteLevel: 1, gamma: 0))
        let transfer = try BT1886Transfer(blackLevel: 0, whiteLevel: 1, gamma: 2.4)
        XCTAssertThrowsError(try transfer.encodeDisplayToLuminance(.nan))
        XCTAssertThrowsError(try transfer.decodeLuminanceToDisplay(1.1))
        XCTAssertEqual(try transfer.encodeDisplayToLuminance(-0.0).bitPattern, 0)
    }
}
