import XCTest
import LUTCore
import LUTSharedUI
import LUTProject
import LUTCatalog

@MainActor
final class SessionContractsTests: XCTestCase {
    func testProjectEditsPreserveParameterizedInputAndPersistAfterOutputSwitch() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let gamma = try ParameterizedGammaSettings(exponent: 2.2, linearSlope: 4.5,
                                                   offset: 0.1, linearCut: 0.02)
        let settings = TransformSettings(
            inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 1,
            inputGamma: gamma, outputGamma: gamma)
        let project = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-gamma-editor-\(UUID().uuidString).lutcalc")
        defer { try? FileManager.default.removeItem(at: url) }
        try ProjectStore.saveNew(project, at: url, catalog: catalog)
        let session = EditorSession()
        try session.openProject(at: url)
        session.setInputRange(.video)
        session.exposureDraft = "2"
        XCTAssertTrue(session.commitExposure())
        XCTAssertEqual(session.currentSettings?.inputGamma, gamma)
        XCTAssertEqual(session.currentSettings?.outputGamma, gamma)
        session.setOutputMode(.linearAP0)
        XCTAssertEqual(session.currentSettings?.inputGamma, gamma)
        XCTAssertNil(session.currentSettings?.outputGamma)
        try session.saveProject()
        let reopened = try ProjectStore.open(at: url, catalog: catalog)
        XCTAssertEqual(reopened.settings.inputGamma, gamma)
        XCTAssertNil(reopened.settings.outputGamma)
        XCTAssertEqual(reopened.settings.exposureStops, 2)
    }
    func testExportSnapshotDoesNotChangeWhenEditorChanges() throws {
        let session = EditorSession()
        let request = try session.makeSnapshot()
        session.exposureDraft = "2"
        XCTAssertTrue(session.commitExposure())
        XCTAssertEqual(request.plan.settings.exposureStops, 1)
        XCTAssertEqual(session.exposureStops, 2)
        XCTAssertEqual(session.revision, 1)
    }

    func testIncompleteNumericDraftDoesNotCommit() throws {
        let session = EditorSession()
        session.exposureDraft = "-"
        XCTAssertFalse(session.commitExposure())
        XCTAssertEqual(session.exposureStops, 1)
        XCTAssertEqual(session.revision, 0)
    }

    func testEditingPreservesSavedBradfordChoice() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(
            inputTransfer: .appleLog2, outputTransfer: .linearScene,
            inputSpace: .appleWideGamut, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1,
            adaptation: .bradford)
        let project = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-bradford-session-\(UUID().uuidString).lutcalc")
        defer { try? FileManager.default.removeItem(at: url) }
        try ProjectStore.saveNew(project, at: url, catalog: catalog)
        let session = EditorSession()
        try session.openProject(at: url)
        XCTAssertEqual(session.currentSettings?.adaptation, .bradford)
        session.setInputRange(.video)
        XCTAssertEqual(session.currentSettings?.adaptation, .bradford)
        session.setOutputMode(.dlog2DGamut2)
        XCTAssertEqual(session.currentSettings?.adaptation, .bradford)
        session.exposureDraft = "2"
        XCTAssertTrue(session.commitExposure())
        XCTAssertEqual(session.currentSettings?.adaptation, .bradford)
        try session.saveProject()
        XCTAssertEqual(try ProjectStore.open(at: url, catalog: catalog).settings.adaptation, .bradford)
    }

    func testOtherProjectResourceDoesNotBlockEditorSnapshot() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let resourcePath = "Resources/notes.bin"
        let resourceBytes = Data("unrelated project resource".utf8)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-other-asset-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("notes.bin")
        try resourceBytes.write(to: source)
        let project = root.appendingPathComponent("notes.lutcalc")
        let initial = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: initial.id, settings: initial.settings,
                                       cubeSize: initial.cubeSize, domain: initial.domain,
                                       assetHashes: [resourcePath: ProjectAssets.sha256(of: resourceBytes)],
                                       assetRoles: [resourcePath: .other])
        try ProjectStore.saveNew(manifest, at: project, catalog: catalog,
                                 assetSources: [resourcePath: source])
        let session = EditorSession()
        try session.openProject(at: project)
        let request = try session.makeSnapshot()
        XCTAssertEqual(request.plan.settings, manifest.settings)
        XCTAssertEqual(request.size, manifest.cubeSize)
    }

    func testUnitOneDimensionalUserLUTIsIncludedInEditorSnapshot() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-editor-user-lut-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("user.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: source)
        let assetPath = "Resources/user.cube"
        let base = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: base.id, settings: base.settings,
                                       cubeSize: base.cubeSize, domain: base.domain,
                                       assetHashes: [assetPath: try ProjectAssets.sha256(of: source)],
                                       assetRoles: [assetPath: .userLUT])
        let projectURL = root.appendingPathComponent("user.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(manifest, at: projectURL, catalog: catalog,
                                 assetSources: [assetPath: source])
        let session = EditorSession()
        try session.openProject(at: projectURL)
        let request = try session.makeSnapshot()
        XCTAssertEqual(request.postLUT?.dimension, .one)
        XCTAssertEqual(request.postLUT?.domain, .unit)
    }
}
