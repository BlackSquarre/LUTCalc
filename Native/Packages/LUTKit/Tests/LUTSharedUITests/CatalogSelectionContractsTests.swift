import XCTest
import LUTCore
import LUTProject
import LUTSharedUI

@MainActor
final class CatalogSelectionContractsTests: XCTestCase {
    func testInputAndOutputCatalogSelectionsPersistAndSupportUndoRedo() throws {
        var document = LUTProjectDocument()
        let original = document.manifest
        let selectedInput = original.settings
            .withInput(transfer: .sonySLog3, space: .sonySGamut3Cine)
        var selectedOutput = selectedInput
            .withOutput(transfer: .arriLogC4, space: .arriWideGamut4)

        try document.apply(ProjectManifest(
            id: original.id, settings: selectedOutput,
            cubeSize: original.cubeSize, domain: original.domain,
            assetHashes: original.assetHashes, assetRoles: original.assetRoles))
        XCTAssertEqual(document.manifest.settings.inputTransfer, .sonySLog3)
        XCTAssertEqual(document.manifest.settings.inputSpace, .sonySGamut3Cine)
        XCTAssertEqual(document.manifest.settings.outputTransfer, .arriLogC4)
        XCTAssertEqual(document.manifest.settings.outputSpace, .arriWideGamut4)
        _ = try document.makeGenerationRequest()

        XCTAssertTrue(document.undo())
        XCTAssertEqual(document.manifest, original)
        XCTAssertTrue(document.redo())
        XCTAssertEqual(document.manifest.settings, selectedOutput)

        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest, document.manifest)

        selectedOutput = selectedOutput.withInput(transfer: .parameterizedGamma, space: .srgb)
        XCTAssertThrowsError(try document.apply(ProjectManifest(
            id: document.manifest.id, settings: selectedOutput,
            cubeSize: document.manifest.cubeSize, domain: document.manifest.domain,
            assetHashes: document.manifest.assetHashes,
            assetRoles: document.manifest.assetRoles))) { error in
            XCTAssertEqual(error as? ProjectError, .invalidSettings)
        }
        XCTAssertEqual(document.manifest.settings, reopened.manifest.settings)
    }
}
