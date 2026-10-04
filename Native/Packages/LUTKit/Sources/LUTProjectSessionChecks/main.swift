import Foundation
import LUTCore
import LUTCatalog
import LUTProject

private enum Failure: Error { case mismatch(String) }

private func settings(_ exposure: Double) -> TransformSettings {
    TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                      inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                      inputRange: .data, outputRange: .data,
                      exposureStops: exposure)
}

do {
    let catalog = try AlgorithmCatalog.builtIn()
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("lutcalc-project-session-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }

    let original = ProjectManifest(settings: settings(0.0), cubeSize: 17, domain: .unit)
    var editor = try ProjectEditingSession(new: original, catalog: catalog)
    let snapshot = editor.current
    let negativeZero = ProjectManifest(id: original.id, settings: settings(-0.0),
                                       cubeSize: 17, domain: .unit)
    try editor.apply(negativeZero)
    guard editor.isDirty, editor.canUndo, editor.revision == 1,
          editor.current.settings.exposureStops.bitPattern == (-0.0).bitPattern,
          snapshot.settings.exposureStops.bitPattern == 0.0.bitPattern else {
        throw Failure.mismatch("signed zero edit or snapshot")
    }
    guard editor.undo(), editor.current.settings.exposureStops.bitPattern == 0.0.bitPattern,
          editor.redo(), editor.current.settings.exposureStops.bitPattern == (-0.0).bitPattern,
          editor.revision == 3 else { throw Failure.mismatch("undo/redo exact Double") }

    let savedURL = directory.appendingPathComponent("primary.lutcalc", isDirectory: true)
    try editor.save(to: savedURL)
    guard !editor.isDirty, editor.url == savedURL.standardizedFileURL,
          try ProjectStore.open(at: savedURL, catalog: catalog).settings.exposureStops.bitPattern
              == (-0.0).bitPattern else { throw Failure.mismatch("new save exact Double") }

    var firstWindow = try ProjectEditingSession(opening: savedURL, catalog: catalog)
    var secondWindow = try ProjectEditingSession(opening: savedURL, catalog: catalog)
    let positiveZero = ProjectManifest(id: original.id, settings: settings(0.0),
                                       cubeSize: 17, domain: .unit)
    try firstWindow.apply(positiveZero)
    try firstWindow.save()
    let different = ProjectManifest(id: original.id, settings: settings(1.0),
                                    cubeSize: 33, domain: .unit)
    try secondWindow.apply(different)
    do {
        try secondWindow.save()
        throw Failure.mismatch("stale signed-zero save accepted")
    } catch ProjectError.concurrentModification {}
    guard secondWindow.isDirty, secondWindow.current == different,
          try ProjectStore.open(at: savedURL, catalog: catalog).settings.exposureStops.bitPattern
              == 0.0.bitPattern else { throw Failure.mismatch("conflict damaged edit or file") }

    let assetFile = directory.appendingPathComponent("user.cube")
    let assetBytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
    try assetBytes.write(to: assetFile)
    let assetPath = "Resources/user.cube"
    let assetHash = try ProjectAssets.sha256(of: assetFile)
    let assetManifest = ProjectManifest(settings: settings(0.1), cubeSize: 17,
                                        domain: .unit, assetHashes: [assetPath: assetHash],
                                        assetRoles: [assetPath: .userLUT])
    let assetProjectURL = directory.appendingPathComponent("with-asset.lutcalc", isDirectory: true)
    try ProjectStore.saveNew(assetManifest, at: assetProjectURL, catalog: catalog,
                             assetSources: [assetPath: assetFile])
    try FileManager.default.removeItem(at: assetFile)
    var assetEditor = try ProjectEditingSession(opening: assetProjectURL, catalog: catalog)
    let copiedURL = directory.appendingPathComponent("copied.lutcalc", isDirectory: true)
    try assetEditor.save(to: copiedURL)
    try FileManager.default.removeItem(at: assetProjectURL)
    guard try ProjectStore.open(at: copiedURL, catalog: catalog) == assetManifest,
          try Data(contentsOf: copiedURL.appendingPathComponent(assetPath)) == assetBytes else {
        throw Failure.mismatch("save-as lost embedded user asset")
    }
    print("H12 项目编辑会话通过：Double 符号零、撤销/重做、双窗口冲突、自包含资源另存为")

    let oversizedProject = directory.appendingPathComponent("oversized.lutcalc", isDirectory: true)
    try FileManager.default.createDirectory(at: oversizedProject, withIntermediateDirectories: false)
    try Data(repeating: 0x20, count: ProjectCodec.maxManifestBytes + 1)
        .write(to: oversizedProject.appendingPathComponent("manifest.json"))
    do {
        _ = try ProjectStore.open(at: oversizedProject, catalog: catalog)
        throw Failure.mismatch("oversized native project manifest accepted")
    } catch ProjectError.manifestSizeLimit {}
} catch {
    fputs("LUTProjectSessionChecks: \(error)\n", stderr)
    exit(1)
}
