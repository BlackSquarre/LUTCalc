import XCTest
@testable import LUTCore
@testable import LUTCatalog

/// 审计契约：BT.601 525/625 transfer 不能仅凭与 Rec.709 相同的候选分段式注册为别名。
final class BT601TransferAuditContractsTests: XCTestCase {
    func testBT601TransferIsNotSilentlyAliasedToRec709Legacy() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertNil(catalog.transfer(named: "BT.601 525"))
        XCTAssertNil(catalog.transfer(named: "BT.601 625"))
        XCTAssertNotEqual(TransferID.rec709LUTCalcLegacy.rawValue, "bt601.525.v1")
        XCTAssertNotEqual(TransferID.rec709LUTCalcLegacy.rawValue, "bt601.625.v1")
    }

    func testRec709CandidateProbeIsRecordedWithoutClaimingBT601Identity() throws {
        let expected: [(Double, Double)] = [
            (0.0, 0.0), (0.018, 0.08124794403514048),
            (0.18, 0.40900772886415044), (1.0, 1.0),
        ]
        for (scene, encoded) in expected {
            XCTAssertEqual(try Rec709Transfer.encodeLegacy(scene), encoded, accuracy: 2e-15)
        }
        let range = try CodeRange.videoRGB(bitDepth: 8)
        XCTAssertEqual(range.blackCode, 16)
        XCTAssertEqual(range.whiteCode, 235)
        XCTAssertEqual(range.maxCode, 255)
    }
}
