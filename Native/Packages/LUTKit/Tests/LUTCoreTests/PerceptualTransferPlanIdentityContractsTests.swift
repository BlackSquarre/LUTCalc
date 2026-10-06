import XCTest
@testable import LUTCore

final class PerceptualTransferPlanIdentityContractsTests: XCTestCase {
    private func version(
        inputTransfer: TransferID,
        outputTransfer: TransferID,
        inputSpace: ColorSpaceID,
        outputSpace: ColorSpaceID
    ) throws -> String {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: inputTransfer,
            outputTransfer: outputTransfer,
            inputSpace: inputSpace,
            outputSpace: outputSpace,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0
        )).planVersion
    }

    func testCIEPlanIdentityIncludesDirectionTransfersAndBothColorSpaces() throws {
        let forward = try version(
            inputTransfer: .cieLStar,
            outputTransfer: .linearScene,
            inputSpace: .rec2020,
            outputSpace: .displayP3
        )
        let reverse = try version(
            inputTransfer: .linearScene,
            outputTransfer: .cieLStar,
            inputSpace: .displayP3,
            outputSpace: .rec2020
        )
        let alternateInput = try version(
            inputTransfer: .cieLStar,
            outputTransfer: .linearScene,
            inputSpace: .proPhoto,
            outputSpace: .displayP3
        )
        let alternateOutput = try version(
            inputTransfer: .cieLStar,
            outputTransfer: .linearScene,
            inputSpace: .rec2020,
            outputSpace: .proPhoto
        )

        XCTAssertNotEqual(forward, reverse)
        XCTAssertNotEqual(forward, alternateInput)
        XCTAssertNotEqual(forward, alternateOutput)
        for identity in [forward, reverse] {
            XCTAssertTrue(identity.contains(TransferID.cieLStar.rawValue))
            XCTAssertTrue(identity.contains(TransferID.linearScene.rawValue))
            XCTAssertTrue(identity.contains(ColorSpaceID.rec2020.rawValue))
            XCTAssertTrue(identity.contains(ColorSpaceID.displayP3.rawValue))
        }
    }

    func testProPhotoPlanIdentityIncludesDirectionTransfersAndBothColorSpaces() throws {
        let forward = try version(
            inputTransfer: .proPhoto,
            outputTransfer: .linearScene,
            inputSpace: .proPhoto,
            outputSpace: .rec2020
        )
        let reverse = try version(
            inputTransfer: .linearScene,
            outputTransfer: .proPhoto,
            inputSpace: .rec2020,
            outputSpace: .proPhoto
        )
        let alternateInput = try version(
            inputTransfer: .proPhoto,
            outputTransfer: .linearScene,
            inputSpace: .displayP3,
            outputSpace: .rec2020
        )
        let alternateOutput = try version(
            inputTransfer: .proPhoto,
            outputTransfer: .linearScene,
            inputSpace: .proPhoto,
            outputSpace: .displayP3
        )

        XCTAssertNotEqual(forward, reverse)
        XCTAssertNotEqual(forward, alternateInput)
        XCTAssertNotEqual(forward, alternateOutput)
        for identity in [forward, reverse] {
            XCTAssertTrue(identity.contains(TransferID.proPhoto.rawValue))
            XCTAssertTrue(identity.contains(TransferID.linearScene.rawValue))
            XCTAssertTrue(identity.contains(ColorSpaceID.proPhoto.rawValue))
            XCTAssertTrue(identity.contains(ColorSpaceID.rec2020.rawValue))
        }
    }
}
