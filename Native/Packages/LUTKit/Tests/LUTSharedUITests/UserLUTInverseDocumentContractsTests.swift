import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTProject
import LUTSharedUI

@MainActor
final class UserLUTInverseDocumentContractsTests: XCTestCase {
    func testStoredCubicInverseSurvivesDocumentRoundTripAndGenerationSnapshot() throws {
        let bytes = Data("LUT_1D_SIZE 4\n0 0 0\n0.25 0.25 0.25\n0.75 0.75 0.75\n1 1 1\n".utf8)
        let imported = try NativeUserLUTLoader.parse(bytes, named: "inverse.cube")
        var document = LUTProjectDocument()
        let path = try document.storeImportedUserLUT(imported)
        try document.applyUserLUTInputInverse(UserLUTInputInverseSettings(
            assetPath: path, interpolation: .tricubicLegacyV1))
        let request = try document.makeGenerationRequest()
        XCTAssertNotNil(request.inputTransferInverse)
        XCTAssertNil(request.inputShaper)

        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest.userLUTInputInverse,
                       document.manifest.userLUTInputInverse)
        XCTAssertNotNil(try reopened.makeGenerationRequest().inputTransferInverse)
    }

    func testInverseCannotBeEnabledWithoutTheMatchingStoredAsset() throws {
        var document = LUTProjectDocument()
        XCTAssertThrowsError(try document.applyUserLUTInputInverse(
            UserLUTInputInverseSettings(assetPath: "Resources/missing.cube",
                                        interpolation: .tricubicLegacyV1))) { error in
            XCTAssertEqual(error as? ProjectError, .invalidAssetRoles)
        }
    }

    func testLACubeAnalysisSemanticsSurviveProjectReopenIntoInversePlan() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                             RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)],
                                   title: "analysis")
        let analysis = LUTAnalysisFile(title: "analysis", transferLUT: transfer,
            colourLUT: nil,
            transferMetadata: LUTAnalysisSectionMetadata(inputRange: "109",
                                                          inputMinimum: -0.25,
                                                          inputMaximum: 1.25,
                                                          interpolation: "trilinear"),
            colourMetadata: nil, sourceFormat: "lacube")
        let bytes = Data(try LACubeWriter.serialize(analysis).utf8)
        let imported = try NativeUserLUTLoader.parse(bytes, named: "analysis.lacube")
        var document = LUTProjectDocument()
        let path = try document.storeImportedUserLUT(imported)
        try document.applyUserLUTInputInverse(UserLUTInputInverseSettings(
            assetPath: path, interpolation: .tricubicLegacyV1))
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        let metadata = try XCTUnwrap(try reopened.makeGenerationRequest().inputTransferInverse?.metadata)
        XCTAssertEqual(metadata.transfer.inputRange, .extended)
        XCTAssertEqual(metadata.transfer.inputBounds, -0.25...1.25)
        XCTAssertEqual(metadata.quantization, .textualDouble)
    }
}
