import XCTest
@testable import LUTCore

final class BBCWHP283ContractsTests: XCTestCase {
    func testFixedRegistrationsAndDerivedParameters() throws {
        let four = BBCWHP283Transfer.percent400
        let eight = BBCWHP283Transfer.percent800
        XCTAssertEqual(four.m, 0.139401137752, accuracy: 0)
        XCTAssertEqual(eight.m, 0.097401889128, accuracy: 0)
        for transfer in [four, eight] {
            XCTAssertEqual(transfer.n, sqrt(transfer.m) / 2, accuracy: 0)
            XCTAssertEqual(transfer.r, sqrt(transfer.m) * (1 - log(sqrt(transfer.m))), accuracy: 0)
            XCTAssertEqual(transfer.e, sqrt(transfer.m), accuracy: 0)
            XCTAssertEqual(transfer.systemGamma, 1, accuracy: 0)
        }
    }

    func testStrictForwardAndInverseBoundaries() throws {
        let transfer = BBCWHP283Transfer.percent400
        let m = transfer.m
        XCTAssertEqual(try transfer.encodeLinearToLegal(m.nextDown), sqrt(m.nextDown), accuracy: 1e-15)
        XCTAssertEqual(try transfer.encodeLinearToLegal(m), sqrt(m), accuracy: 1e-15)
        XCTAssertEqual(try transfer.encodeLinearToLegal(m.nextUp), transfer.n * log(m.nextUp) + transfer.r, accuracy: 1e-15)
        let e = transfer.e
        XCTAssertEqual(try transfer.decodeLegalToLinear(e.nextDown), pow(e.nextDown, 2), accuracy: 1e-15)
        XCTAssertEqual(try transfer.decodeLegalToLinear(e), pow(e, 2), accuracy: 1e-15)
        XCTAssertEqual(try transfer.decodeLegalToLinear(e.nextUp), exp((e.nextUp - transfer.r) / transfer.n), accuracy: 1e-15)
        XCTAssertEqual(try transfer.encodeLinearToLegal(0), 0, accuracy: 0)
        XCTAssertEqual(try transfer.encodeLinearToLegal(-1), 0, accuracy: 0)
    }

    func testDataWrapperRoundTripsBothRegistrations() throws {
        for transfer in [BBCWHP283Transfer.percent400, BBCWHP283Transfer.percent800] {
            for value in [-1.0, 0.0, transfer.m.nextDown, transfer.m, transfer.m.nextUp, 0.18, 1.0] {
                let data = try transfer.encodeLegacyToData(value)
                let expected = value > 0 ? value : 0
                XCTAssertEqual(try transfer.decodeDataToLegacy(data), expected, accuracy: 3e-14)
            }
        }
    }

    func testParametersRejectInvalidValuesAndNonFiniteResults() throws {
        XCTAssertThrowsError(try BBCWHP283Transfer(m: 0))
        XCTAssertThrowsError(try BBCWHP283Transfer(m: -.infinity))
        XCTAssertThrowsError(try BBCWHP283Transfer(m: 0.1, systemGamma: 0))
        XCTAssertThrowsError(try BBCWHP283Transfer(m: 0.1, systemGamma: .nan))
        XCTAssertThrowsError(try BBCWHP283Transfer.percent400.encodeLinearToLegal(.nan))
        XCTAssertThrowsError(try BBCWHP283Transfer.percent800.decodeDataToLegacy(.infinity))
    }

    func testPlanIdentityIncludesDirectionalColorSpaces() throws {
        let base = TransformSettings(inputTransfer: .bbcWHP283400, outputTransfer: .linearScene,
                                     inputSpace: .rec2020, outputSpace: .rec2020,
                                     inputRange: .data, outputRange: .data, exposureStops: 0)
        let baseline = try TransformPlan(settings: base).planVersion
        XCTAssertNotEqual(baseline, try TransformPlan(settings: base.withInput(transfer: .bbcWHP283400, space: .srgb)).planVersion)
        XCTAssertNotEqual(baseline, try TransformPlan(settings: base.withOutput(transfer: .linearScene, space: .srgb)).planVersion)
        XCTAssertTrue(baseline.contains(":inSpace:" + ColorSpaceID.rec2020.rawValue))
        XCTAssertTrue(baseline.contains(":outSpace:" + ColorSpaceID.rec2020.rawValue))
    }
}
