import XCTest
import LUTCore
import LUTProject
import LUTSharedUI

@MainActor
final class ParameterizedGammaEditorContractsTests: XCTestCase {
    func testInputAndOutputDraftsCommitAtomicallyAndSurvivePackageRoundTrip() throws {
        var document = LUTProjectDocument()
        let initial = document.manifest
        let input = ParameterizedGammaDraft(exponent: "2.4", linearSlope: "4.5",
                                            offset: "0.1", linearCut: "0.02", encodedCut: "0.09")
        try document.applyParameterizedGamma(input, slot: .input, expectedRevision: document.revision)
        XCTAssertEqual(document.manifest.settings.inputTransfer, .parameterizedGamma)
        XCTAssertEqual(document.manifest.settings.inputGamma?.encodedCut, 0.09)
        XCTAssertEqual(document.manifest.settings.outputTransfer, initial.settings.outputTransfer)
        let output = ParameterizedGammaDraft(exponent: "1.8", linearSlope: "16",
                                             offset: "0", linearCut: "0", encodedCut: "")
        try document.applyParameterizedGamma(output, slot: .output, expectedRevision: document.revision)
        XCTAssertEqual(document.manifest.settings.inputGamma?.exponent, 2.4)
        XCTAssertEqual(document.manifest.settings.outputTransfer, .parameterizedGamma)
        XCTAssertEqual(document.manifest.settings.outputGamma?.exponent, 1.8)
        XCTAssertNil(document.manifest.settings.outputGamma?.encodedCut)
        XCTAssertEqual(document.manifest.id, initial.id)
        XCTAssertEqual(document.manifest.cubeSize, initial.cubeSize)
        XCTAssertEqual(document.manifest.domain, initial.domain)
        _ = try document.makeGenerationRequest()
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest, document.manifest)
        XCTAssertTrue(document.undo())
        XCTAssertNil(document.manifest.settings.outputGamma)
        XCTAssertTrue(document.redo())
        XCTAssertEqual(document.manifest.settings.outputGamma?.exponent, 1.8)
    }

    func testParameterizedGammaEditsPreserveHLGOOTFSettings() throws {
        let ootf = HLGOOTFSettings(inputPeakNits: 800, outputPeakNits: 1000,
                                   inputBlackNits: 2, outputBlackNits: 0,
                                   scale: .normalizedBy1000, bbcOutput: true)
        let base = TransformSettings(inputTransfer: .linearScene,
                                     outputTransfer: .rec2100HLG,
                                     inputSpace: .rec2020, outputSpace: .rec2020,
                                     inputRange: .data, outputRange: .data,
                                     exposureStops: 0, hlgOOTF: ootf)
        var document = try LUTProjectDocument(new: ProjectManifest(settings: base,
                                                                    cubeSize: 17,
                                                                    domain: .unit))
        let draft = ParameterizedGammaDraft(exponent: "2.4", linearSlope: "4.5",
                                            offset: "0.1", linearCut: "0.02", encodedCut: "0.09")
        try document.applyParameterizedGamma(draft, slot: .input, expectedRevision: document.revision)
        XCTAssertEqual(document.manifest.settings.hlgOOTF, ootf)
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest.settings.hlgOOTF, ootf)
    }

    func testInvalidAndStaleDraftsLeaveProjectUnchanged() throws {
        var document = LUTProjectDocument()
        let old = document.manifest
        let revision = document.revision
        let badNumber = ParameterizedGammaDraft(exponent: "NaN", linearSlope: "1",
                                                offset: "0", linearCut: "0", encodedCut: "")
        XCTAssertThrowsError(try document.applyParameterizedGamma(
            badNumber, slot: .input, expectedRevision: revision)) {
            XCTAssertEqual($0 as? ParameterizedGammaDraftError, .invalidNumber)
        }
        let badDomain = ParameterizedGammaDraft(exponent: "0", linearSlope: "1",
                                                offset: "0", linearCut: "0", encodedCut: "")
        XCTAssertThrowsError(try document.applyParameterizedGamma(
            badDomain, slot: .input, expectedRevision: revision))
        XCTAssertEqual(document.manifest, old)
        XCTAssertEqual(document.revision, revision)
        let valid = ParameterizedGammaDraft(exponent: "2.2", linearSlope: "1",
                                            offset: "0", linearCut: "0", encodedCut: "")
        try document.applyParameterizedGamma(valid, slot: .input, expectedRevision: revision)
        let after = document.manifest
        XCTAssertThrowsError(try document.applyParameterizedGamma(
            valid, slot: .output, expectedRevision: revision)) {
            XCTAssertEqual($0 as? ParameterizedGammaDraftError, .staleRevision)
        }
        XCTAssertEqual(document.manifest, after)
    }
}
