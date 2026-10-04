import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTProject
import LUTCatalog
import LUTSharedUI

@MainActor
final class UserLUTProjectAssetContractsTests: XCTestCase {
    func testApplyingCatalogPresetPreservesProjectEnvelopeAndSupportsUndo() throws {
        let bytes = Data("project notes".utf8)
        let path = "Resources/notes.bin"
        let original = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: original.id, settings: original.settings,
                                       cubeSize: 33, domain: .unit,
                                       assetHashes: [path: ProjectAssets.sha256(of: bytes)],
                                       assetRoles: [path: .other])
        var document = try LUTProjectDocument(new: manifest, assetContents: [path: bytes])
        let preset = try XCTUnwrap(AlgorithmCatalog.builtIn().preset(named: "sony.slog3-to-linear-ap0.v1"))
        try document.applyPreset(preset)
        XCTAssertEqual(document.manifest.settings, preset.settings)
        XCTAssertEqual(document.manifest.id, manifest.id)
        XCTAssertEqual(document.manifest.cubeSize, 33)
        XCTAssertEqual(document.manifest.domain, manifest.domain)
        XCTAssertEqual(document.manifest.assetHashes, manifest.assetHashes)
        XCTAssertEqual(document.manifest.assetRoles, manifest.assetRoles)
        XCTAssertEqual(document.assetContents[path], bytes)
        XCTAssertTrue(document.undo())
        XCTAssertEqual(document.manifest, manifest)
        XCTAssertTrue(document.redo())
        XCTAssertEqual(document.manifest.settings, preset.settings)
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest, document.manifest)
        XCTAssertEqual(reopened.assetContents, document.assetContents)
    }

    func testEveryPresentedCatalogPresetCanBecomeAProjectAndGenerationRequest() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertFalse(catalog.presets.isEmpty)
        for preset in catalog.presets {
            var document = LUTProjectDocument()
            try document.applyPreset(preset)
            let request = try document.makeGenerationRequest()
            XCTAssertEqual(request.plan.settings, preset.settings, preset.id)
            XCTAssertEqual(request.size, 17, preset.id)
        }
    }

    func testRangeAndAdaptationChangesPersistWithGammaAndKeepResources() throws {
        let gamma = try ParameterizedGammaSettings(exponent: 2.2, linearSlope: 1,
                                                   offset: 0, linearCut: 0)
        let initial = LUTProjectDocument().manifest
        let settings = TransformSettings(
            inputTransfer: .parameterizedGamma, outputTransfer: .parameterizedGamma,
            inputSpace: .srgb, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            inputGamma: gamma, outputGamma: gamma)
        let path = "Resources/notes.bin"
        let bytes = Data("notes".utf8)
        let manifest = ProjectManifest(id: initial.id, settings: settings,
                                       cubeSize: 17, domain: .unit,
                                       assetHashes: [path: ProjectAssets.sha256(of: bytes)],
                                       assetRoles: [path: .other])
        var document = try LUTProjectDocument(new: manifest, assetContents: [path: bytes])
        let old = document.manifest
        let changed = settings.withOutputRange(.video).withRangeBitDepth(12)
            .withAdaptation(.bradford)
        try document.apply(ProjectManifest(id: old.id, settings: changed,
                                           cubeSize: old.cubeSize, domain: old.domain,
                                           assetHashes: old.assetHashes, assetRoles: old.assetRoles))
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.manifest.settings, changed)
        XCTAssertEqual(reopened.manifest.settings.inputGamma, gamma)
        XCTAssertEqual(reopened.manifest.settings.outputGamma, gamma)
        XCTAssertEqual(reopened.assetContents[path], bytes)
        XCTAssertEqual(try reopened.makeGenerationRequest().plan.settings, changed)
        XCTAssertTrue(document.undo())
        XCTAssertEqual(document.manifest, old)
    }
    func testImportedLUTCoexistsWithUnrelatedProjectResource() throws {
        let unrelatedPath = "Resources/reference.cube"
        let unrelatedBytes = Data("project notes".utf8)
        let initial = LUTProjectDocument()
        let original = initial.manifest
        let manifest = ProjectManifest(id: original.id, settings: original.settings,
                                       cubeSize: original.cubeSize, domain: original.domain,
                                       assetHashes: [unrelatedPath: ProjectAssets.sha256(of: unrelatedBytes)])
        var document = try LUTProjectDocument(new: manifest,
                                              assetContents: [unrelatedPath: unrelatedBytes])
        XCTAssertTrue(document.storedUserLUTPaths.isEmpty)
        let baseline = try LUTProjectDocument().makeGenerationRequest()
        let withOtherAsset = try document.makeGenerationRequest()
        let probe = try RGB64(0.25, 0.5, 0.75)
        XCTAssertEqual(try withOtherAsset.plan.evaluate(probe), try baseline.plan.evaluate(probe))
        let bytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 2 3\n".utf8)
        let imported = try NativeUserLUTLoader.parse(bytes, named: "chosen.cube")
        let lutPath = try document.storeImportedUserLUT(imported)
        XCTAssertEqual(document.storedUserLUTPaths, [lutPath])
        XCTAssertEqual(document.assetContents[unrelatedPath], unrelatedBytes)
        XCTAssertEqual(document.manifest.assetHashes[unrelatedPath],
                       ProjectAssets.sha256(of: unrelatedBytes))
        XCTAssertEqual(document.manifest.assetRoles[unrelatedPath], .other)
        XCTAssertEqual(document.manifest.assetRoles[lutPath], .userLUT)
        let reopened = try LUTProjectDocument(fileWrapper: document.makeFileWrapper())
        XCTAssertEqual(reopened.assetContents[unrelatedPath], unrelatedBytes)
        XCTAssertEqual(reopened.manifest.assetRoles, document.manifest.assetRoles)
        XCTAssertEqual(reopened.storedUserLUTPaths, [lutPath])
        XCTAssertThrowsError(try reopened.inspectStoredUserLUT(at: unrelatedPath)) {
            XCTAssertEqual($0 as? UserLUTImportError, .notStoredUserLUT)
        }
        XCTAssertEqual(try reopened.inspectStoredUserLUT(at: lutPath).sample(
            RGB64(0.5, 0.25, 0.75), interpolation: .trilinear, outside: .reject),
                       try RGB64(0.5, 0.5, 2.25))
    }

    func testOtherAssetProjectExportsUnchangedCube() async throws {
        let path = "Resources/notes.bin"
        let bytes = Data("not a LUT".utf8)
        let initial = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: initial.id, settings: initial.settings,
                                       cubeSize: initial.cubeSize, domain: initial.domain,
                                       assetHashes: [path: ProjectAssets.sha256(of: bytes)],
                                       assetRoles: [path: .other])
        let document = try LUTProjectDocument(new: manifest, assetContents: [path: bytes])
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-other-asset-\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: output) }
        let request = try document.makeGenerationRequest()
        let written = try await NativeExportService().generate(request, to: output)
        XCTAssertEqual(written, 4_913)
        let readback = try CubeParser.parse(url: output)
        let grid = try Grid3D(size: 17, domain: .unit)
        var maximumAbsoluteError = 0.0
        for index in [0, 1, 16, 2_456, 4_912] {
            let expected = try request.plan.evaluate(grid.coordinate(at: index))
            let actual = readback.samples[index]
            maximumAbsoluteError = max(maximumAbsoluteError,
                                       abs(actual.r - expected.r),
                                       abs(actual.g - expected.g),
                                       abs(actual.b - expected.b))
            XCTAssertEqual(actual.r, expected.r, accuracy: 2e-12)
            XCTAssertEqual(actual.g, expected.g, accuracy: 2e-12)
            XCTAssertEqual(actual.b, expected.b, accuracy: 2e-12)
        }
        print("other asset CUBE five-probe maximum absolute error: \(maximumAbsoluteError)")
        XCTAssertEqual(document.assetContents[path], bytes)
    }

    func testV1PackageMigratesUserLUTRoleAndPreservesOtherAsset() throws {
        let userPath = "Resources/user-00000000-0000-0000-0000-000000000001.cube"
        let otherPath = "Resources/reference.cube"
        let userBytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 2 3\n".utf8)
        let otherBytes = Data("project notes".utf8)
        let initial = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: initial.id, settings: initial.settings,
                                       cubeSize: initial.cubeSize, domain: initial.domain,
                                       assetHashes: [userPath: ProjectAssets.sha256(of: userBytes),
                                                     otherPath: ProjectAssets.sha256(of: otherBytes)],
                                       assetRoles: [userPath: .userLUT, otherPath: .other])
        let document = try LUTProjectDocument(new: manifest,
                                              assetContents: [userPath: userBytes,
                                                              otherPath: otherBytes])
        let wrapper = try document.makeFileWrapper()
        let manifestFile = try XCTUnwrap(wrapper.fileWrappers?["manifest.json"])
        var raw = try JSONSerialization.jsonObject(with: try XCTUnwrap(manifestFile.regularFileContents))
            as! [String: Any]
        raw["schemaVersion"] = 1
        raw.removeValue(forKey: "assetRoles")
        let oldBytes = try JSONSerialization.data(withJSONObject: raw)
        var files = try XCTUnwrap(wrapper.fileWrappers)
        files["manifest.json"] = FileWrapper(regularFileWithContents: oldBytes)
        let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(directoryWithFileWrappers: files))
        XCTAssertEqual(reopened.manifest.assetRoles[userPath], .legacyUserLUT)
        XCTAssertEqual(reopened.manifest.assetRoles[otherPath], .other)
        XCTAssertEqual(reopened.assetContents[otherPath], otherBytes)
        XCTAssertEqual(try reopened.inspectStoredUserLUT(at: userPath).sample(
            RGB64(0.5, 0.25, 0.75), interpolation: .trilinear, outside: .reject),
                       try RGB64(0.5, 0.5, 2.25))
        let saved = try LUTProjectDocument(fileWrapper: reopened.makeFileWrapper())
        XCTAssertEqual(saved.manifest, reopened.manifest)
        XCTAssertEqual(saved.assetContents, reopened.assetContents)
    }

    func testV2RoleOverridesLegacyLookingFilename() throws {
        let path = "Resources/user-00000000-0000-0000-0000-000000000001.cube"
        let bytes = Data("project notes".utf8)
        let initial = LUTProjectDocument().manifest
        let manifest = ProjectManifest(id: initial.id, settings: initial.settings,
                                       cubeSize: initial.cubeSize, domain: initial.domain,
                                       assetHashes: [path: ProjectAssets.sha256(of: bytes)],
                                       assetRoles: [path: .other])
        let document = try LUTProjectDocument(new: manifest, assetContents: [path: bytes])
        XCTAssertTrue(document.storedUserLUTPaths.isEmpty)
        XCTAssertThrowsError(try document.inspectStoredUserLUT(at: path)) {
            XCTAssertEqual($0 as? UserLUTImportError, .notStoredUserLUT)
        }
        XCTAssertThrowsError(try document.makeStoredUserLUTExport()) {
            XCTAssertEqual($0 as? UserLUTImportError, .noImportedLUT)
        }
    }

    func testImportedBytesSurvivePackageRoundtripAndSourceRemoval() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-h07-project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("chosen.cube")
        let bytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 2 3\n".utf8)
        try bytes.write(to: source)
        let imported = try await NativeUserLUTLoader().load(source)
        var document = LUTProjectDocument()
        let previousRevision = document.revision
        let path = try document.storeImportedUserLUT(imported)
        XCTAssertGreaterThan(document.revision, previousRevision)
        XCTAssertTrue(path.hasPrefix("Resources/"))
        XCTAssertEqual(document.manifest.assetHashes[path], ProjectAssets.sha256(of: bytes))
        XCTAssertEqual(document.assetContents[path], bytes)
        let request = try document.makeGenerationRequest()
        XCTAssertNotNil(request.postLUT)
        XCTAssertEqual(request.postLUT?.dimension, .one)

        let package = directory.appendingPathComponent("chosen.lutcalc", isDirectory: true)
        try document.makeFileWrapper().write(to: package, options: .atomic, originalContentsURL: nil)
        try FileManager.default.removeItem(at: source)
        let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: package, options: .immediate))
        XCTAssertEqual(reopened.assetContents[path], bytes)
        let export = try reopened.makeStoredUserLUTExport()
        XCTAssertTrue(export.suggestedFilename.hasSuffix(".cube"))
        XCTAssertEqual(try export.makeFileWrapper().regularFileContents, bytes)
        let exportedFile = directory.appendingPathComponent("exported.cube")
        try export.makeFileWrapper().write(to: exportedFile, options: .atomic,
                                           originalContentsURL: nil)
        XCTAssertEqual(try Data(contentsOf: exportedFile), bytes)
        let inspected = try reopened.inspectStoredUserLUT(at: path)
        let session = UserLUTImportSession()
        session.showStored(inspected)
        XCTAssertEqual(session.loadStatus, .loaded)
        let result = try inspected.sample(RGB64(0.5, 0.25, 0.75),
                                          interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(result, try RGB64(0.5, 0.5, 2.25))
        XCTAssertEqual(try session.sample(RGB64(0.5, 0.25, 0.75),
                                          interpolation: .trilinear, outside: .reject), result)
        XCTAssertNotNil(try reopened.makeGenerationRequest().postLUT)
        let resource = package.appendingPathComponent(path)
        try Data("tampered".utf8).write(to: resource)
        XCTAssertThrowsError(try LUTProjectDocument(fileWrapper: FileWrapper(url: package, options: .immediate))) {
            error in
            XCTAssertEqual(error as? ProjectError, .assetHashMismatch(path))
        }
    }

    func testUnbackedSessionResultCannotBecomeProjectAsset() throws {
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let imported = ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/unbacked.cube"),
                                       format: .cube, lut: lut)
        var document = LUTProjectDocument()
        XCTAssertThrowsError(try document.storeImportedUserLUT(imported))
        let mismatched = ImportedUserLUT(url: imported.url, format: .cube, lut: lut,
            originalBytes: Data("LUT_1D_SIZE 2\n0 0 0\n1 2 3\n".utf8))
        XCTAssertThrowsError(try document.storeImportedUserLUT(mismatched)) { error in
            XCTAssertEqual(error as? UserLUTImportError, .sourceContentMismatch)
        }
        XCTAssertTrue(document.manifest.assetHashes.isEmpty)
        XCTAssertTrue(document.assetContents.isEmpty)
    }
}
