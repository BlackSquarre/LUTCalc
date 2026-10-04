import Foundation
import LUTCore
import LUTCatalog
import LUTProject
import LUTSharedUI

private enum Failure: Error { case mismatch(String) }

do {
    let blank = LUTProjectDocument()
    guard blank.manifest.settings.inputTransfer == .djiDLog2,
          blank.manifest.settings.outputTransfer == .linearScene,
          blank.manifest.cubeSize == 17,
          blank.assetContents.isEmpty else {
        throw Failure.mismatch("new DocumentGroup document defaults")
    }
    let defaultRequest = try blank.makeGenerationRequest()
    guard defaultRequest.size == 17,
          defaultRequest.plan.settings == blank.manifest.settings,
          defaultRequest.domain == .unit else {
        throw Failure.mismatch("new document export snapshot")
    }
    let settings = TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .video, outputRange: .data,
        exposureStops: -0.0, rangeBitDepth: 12
    )
    let asset = Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
    let path = "Resources/user.cube"
    let manifest = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit,
        assetHashes: [path: ProjectAssets.sha256(of: asset)], assetRoles: [path: .userLUT])
    let document = try LUTProjectDocument(new: manifest, assetContents: [path: asset])
    let wrapper = try document.makeFileWrapper()
    let restored = try LUTProjectDocument(fileWrapper: wrapper)
    guard restored.manifest.id == manifest.id,
          restored.manifest.settings.exposureStops.bitPattern == (-0.0).bitPattern,
          restored.manifest.settings.rangeBitDepth == 12,
          restored.assetContents[path] == asset else {
        throw Failure.mismatch("package wrapper roundtrip")
    }
    guard let postLUT = try restored.makeGenerationRequest().postLUT,
          postLUT.dimension == .one else {
        throw Failure.mismatch("unit 1D user LUT missing from export plan")
    }
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("lutcalc-file-document-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    let packageURL = folder.appendingPathComponent("roundtrip.lutcalc", isDirectory: true)
    try wrapper.write(to: packageURL, options: .atomic, originalContentsURL: nil)
    let catalog = try AlgorithmCatalog.builtIn()
    guard try ProjectStore.open(at: packageURL, catalog: catalog) == manifest,
          try Data(contentsOf: packageURL.appendingPathComponent(path)) == asset else {
        throw Failure.mismatch("FileWrapper disk and ProjectStore differ")
    }
    let diskWrapper = try FileWrapper(url: packageURL, options: .immediate)
    let diskDocument = try LUTProjectDocument(fileWrapper: diskWrapper)
    guard diskDocument.manifest == manifest,
          diskDocument.assetContents[path] == asset else {
        throw Failure.mismatch("ProjectStore disk package and FileDocument differ")
    }
    var editing = restored
    let changedSettings = TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .video, outputRange: .data,
        exposureStops: 0.18000000000000002, rangeBitDepth: 12
    )
    let changed = ProjectManifest(id: manifest.id, settings: changedSettings,
        cubeSize: 33, domain: .unit, assetHashes: manifest.assetHashes,
        assetRoles: manifest.assetRoles)
    try editing.apply(changed)
    guard editing.canUndo, editing.undo(),
          editing.manifest.settings.exposureStops.bitPattern == (-0.0).bitPattern,
          editing.redo(),
          editing.manifest.settings.exposureStops.bitPattern == 0.18000000000000002.bitPattern,
          try LUTProjectDocument(fileWrapper: editing.makeFileWrapper()).manifest == changed else {
        throw Failure.mismatch("document undo/redo and persisted snapshot")
    }
    var files = wrapper.fileWrappers ?? [:]
    files["unexpected.txt"] = FileWrapper(regularFileWithContents: Data("extra".utf8))
    do {
        _ = try LUTProjectDocument(fileWrapper: FileWrapper(directoryWithFileWrappers: files))
        throw Failure.mismatch("unknown top-level file accepted")
    } catch ProjectError.invalidPackage {}
    let damaged = Data("changed".utf8)
    let damagedResources = FileWrapper(directoryWithFileWrappers: [
        "user.cube": FileWrapper(regularFileWithContents: damaged)
    ])
    guard let manifestWrapper = files["manifest.json"] else { throw Failure.mismatch("manifest missing") }
    do {
        _ = try LUTProjectDocument(fileWrapper: FileWrapper(directoryWithFileWrappers: [
            "manifest.json": manifestWrapper, "Resources": damagedResources
        ]))
        throw Failure.mismatch("asset hash mismatch accepted")
    } catch ProjectError.assetHashMismatch(path) {}
    let largeManifest = FileWrapper(regularFileWithContents: Data(repeating: 0x20,
        count: LUTProjectDocument.maxManifestBytes + 1))
    do {
        _ = try LUTProjectDocument(fileWrapper: FileWrapper(directoryWithFileWrappers: [
            "manifest.json": largeManifest
        ]))
        throw Failure.mismatch("oversized manifest accepted")
    } catch ProjectError.manifestSizeLimit {}
    print("H12 FileDocument 包适配契约通过：Double 符号零、12-bit、导出快照与用户一维 LUT 阶段、撤销/重做、资源与磁盘互通、未知文件/篡改/超限拒绝")
} catch {
    fputs("LUTDocumentChecks: \(error)\n", stderr)
    exit(1)
}
