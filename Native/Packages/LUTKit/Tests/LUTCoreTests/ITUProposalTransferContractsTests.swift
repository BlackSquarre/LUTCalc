import XCTest
@testable import LUTCore
import LUTCatalog

final class ITUProposalTransferContractsTests: XCTestCase {
    func testRegisteredKneeParametersAndTangentContinuity() throws {
        for transfer in [ITUProposalTransfer.percent400, .percent800] {
            let m = transfer.kneeLinear
            let encodedAtKnee = try transfer.encodeLinearToLegal(m)
            XCTAssertEqual(encodedAtKnee, transfer.kneeEncoded, accuracy: 2e-16)
            XCTAssertEqual(try transfer.encodeLinearToLegal(m.nextDown),
                           1.0993 * pow(m.nextDown, 0.45) - 0.0993, accuracy: 2e-16)
            XCTAssertEqual(try transfer.encodeLinearToLegal(m.nextUp),
                           transfer.shoulderSlope * log(m.nextUp) + transfer.shoulderOffset,
                           accuracy: 2e-16)
            XCTAssertEqual(try transfer.decodeLegalToLinear(encodedAtKnee), m, accuracy: 3e-16)
        }
    }

    func testRec2020ToeAndDataWrapper() throws {
        let transfer = ITUProposalTransfer.percent400
        for value in [-0.1, 0, 0.0181.nextDown, 0.0181, 0.0181.nextUp,
                      transfer.kneeLinear.nextDown, transfer.kneeLinear,
                      transfer.kneeLinear.nextUp, 0.18, 1, 8] {
            let legal = try transfer.encodeLinearToLegal(value)
            let data = try transfer.encodeLegacyToData(value)
            XCTAssertEqual(data, legal * 0.85630498533724 + 0.06256109481916,
                           accuracy: 2e-16)
            if value < 0 || value == 0 || value >= transfer.kneeLinear {
                XCTAssertEqual(try transfer.decodeDataToLegacy(data), value, accuracy: 5e-14)
            }
        }
        // The legacy BT.2020 constants round the encoded toe boundary to
        // 0.08145; the forward OETF's rounded coefficients do not meet it
        // exactly. Preserve that historical branch behavior.
        XCTAssertEqual(try transfer.decodeLegalToLinear(0.08145),
                       pow((0.08145 + 0.0993) / 1.0993, 1 / 0.45), accuracy: 2e-16)
    }

    func testPlansAndCatalogKeepTheTwoRegistrationsDistinct() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "ITU Proposal (400%)")?.id, .ituProposal400)
        XCTAssertEqual(catalog.transfer(named: "ITU Proposal (800%)")?.id, .ituProposal800)

        for id in [TransferID.ituProposal400, .ituProposal800] {
            XCTAssertTrue(id.hasNormalizedDataEncoding)
            let settings = TransformSettings(
                inputTransfer: id, outputTransfer: id,
                inputSpace: .rec2020, outputSpace: .rec2020,
                inputRange: .data, outputRange: .data, exposureStops: 0)
            let plan = try TransformPlan(settings: settings)
            for legacy in [0.0, 0.0181, 0.18, 1.0, 4.0] {
                let encoded = try (id == .ituProposal400 ? ITUProposalTransfer.percent400
                                  : ITUProposalTransfer.percent800).encodeLegacyToData(legacy)
                let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
                XCTAssertEqual(result.r, encoded, accuracy: 4e-14)
            }
        }
    }

    func testPlanIdentityIncludesDirectionalColorSpaces() throws {
        let base = TransformSettings(
            inputTransfer: .ituProposal400, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let alternateInput = base.withInput(transfer: .ituProposal400, space: .srgb)
        let alternateOutput = base.withOutput(transfer: .linearScene, space: .srgb)
        let baseline = try TransformPlan(settings: base).planVersion
        XCTAssertNotEqual(baseline, try TransformPlan(settings: alternateInput).planVersion)
        XCTAssertNotEqual(baseline, try TransformPlan(settings: alternateOutput).planVersion)
        XCTAssertTrue(baseline.contains(":inSpace:" + ColorSpaceID.rec2020.rawValue))
        XCTAssertTrue(baseline.contains(":outSpace:" + ColorSpaceID.rec2020.rawValue))
    }

    func testNonFiniteInputsAreRejected() throws {
        for transfer in [ITUProposalTransfer.percent400, .percent800] {
            for value in [Double.nan, Double.infinity, -Double.infinity] {
                XCTAssertThrowsError(try transfer.encodeLinearToLegal(value))
                XCTAssertThrowsError(try transfer.decodeLegalToLinear(value))
                XCTAssertThrowsError(try transfer.decodeDataToLegacy(value))
            }
        }
    }
}
