import XCTest
@testable import LUTCore

final class ACESProxyContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedCodePointsAndBlackClip() throws {
        for transfer in [ACESProxyTransfer.ten, ACESProxyTransfer.twelve] {
            let maximum = transfer.bitDepth == .ten ? 1023.0 : 4095.0
            let black = transfer.bitDepth == .ten ? 64.0 : 256.0
            XCTAssertEqual(try transfer.encodeLinearAP1ToData(0), black / maximum, accuracy: 0)
            XCTAssertEqual(try transfer.encodeLinearAP1ToData(transfer.lowLinear), black / maximum, accuracy: 0)
            XCTAssertEqual(try transfer.decodeDataToLinearAP1(black / maximum), transfer.lowLinear,
                           accuracy: tolerance)
            XCTAssertEqual(try transfer.decodeDataToLinearAP1(1),
                           exp2(((maximum - (transfer.bitDepth == .ten ? 425.0 : 1700.0))
                                 / (transfer.bitDepth == .ten ? 50.0 : 200.0)) - 2.5) / 0.9,
                           accuracy: tolerance)
        }
    }

    func testTenAndTwelveBitMappingsStayDistinct() throws {
        let ten = try ACESProxyTransfer.ten.encodeLinearAP1ToData(0.18)
        let twelve = try ACESProxyTransfer.twelve.encodeLinearAP1ToData(0.18)
        XCTAssertEqual(ten, (((log2(0.18 * 0.9) + 2.5) * 50.0) + 425.0) / 1023.0,
                       accuracy: tolerance)
        XCTAssertEqual(twelve, (((log2(0.18 * 0.9) + 2.5) * 200.0) + 1700.0) / 4095.0,
                       accuracy: tolerance)
        XCTAssertNotEqual(ten, twelve)
    }

    func testSameSpaceExposurePlansUseTheDeclaredBitDepth() throws {
        let cases: [(TransferID, String, ACESProxyTransfer)] = [
            (.acesProxy10, "minimal-acesproxy10-v1", .ten),
            (.acesProxy12, "minimal-acesproxy12-v1", .twelve),
        ]
        for (id, version, transfer) in cases {
            let settings = TransformSettings(
                inputTransfer: id, outputTransfer: .linearScene,
                inputSpace: .acesAP1, outputSpace: .acesAP1,
                inputRange: .data, outputRange: .data, exposureStops: 1)
            let plan = try TransformPlan(settings: settings)
            XCTAssertEqual(plan.planVersion, version)
            let encoded = try transfer.encodeLinearAP1ToData(0.18)
            XCTAssertEqual(try plan.evaluate(RGB64(encoded, encoded, encoded)).r, 0.36,
                           accuracy: tolerance)
        }
    }

    func testNonFiniteValuesAreRejected() {
        for transfer in [ACESProxyTransfer.ten, ACESProxyTransfer.twelve] {
            for value in [Double.nan, Double.infinity, -Double.infinity] {
                XCTAssertThrowsError(try transfer.encodeLinearAP1ToData(value))
                XCTAssertThrowsError(try transfer.decodeDataToLinearAP1(value))
            }
        }
    }
}
