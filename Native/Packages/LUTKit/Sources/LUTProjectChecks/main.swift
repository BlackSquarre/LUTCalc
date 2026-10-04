import Foundation
import LUTCore
import LUTCatalog
import LUTProject

private enum Failure: Error { case mismatch(String) }

private func mutated(_ source: Data, _ keyPath: [String], _ value: Any) throws -> Data {
    var root = try JSONSerialization.jsonObject(with: source) as! [String: Any]
    if keyPath.count == 1 {
        root[keyPath[0]] = value
    } else {
        var nested = root[keyPath[0]] as! [String: Any]
        nested[keyPath[1]] = value
        root[keyPath[0]] = nested
    }
    return try JSONSerialization.data(withJSONObject: root)
}

do {
    let catalog = try AlgorithmCatalog.builtIn()
    let settings = TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .video, outputRange: .data,
        exposureStops: 0.18000000000000002, rangeBitDepth: 12
    )
    let domain = try LUTDomain(min: RGB64(-0.125, 0, 0), max: RGB64(1.25, 1, 2))
    let first = ProjectManifest(settings: settings, cubeSize: 33, domain: domain)
    let encoded = try ProjectCodec.encode(first, catalog: catalog)
    let decoded = try ProjectCodec.decode(encoded, catalog: catalog)
    guard decoded.id == first.id, decoded.settings == settings, decoded.cubeSize == 33,
          decoded.domain == domain,
          decoded.settings.exposureStops.bitPattern == settings.exposureStops.bitPattern else {
        throw Failure.mismatch("Double/settings roundtrip")
    }
    let bradfordSettings = TransformSettings(
        inputTransfer: .appleLog2, outputTransfer: .linearScene,
        inputSpace: .appleWideGamut, outputSpace: .acesAP0,
        inputRange: .data, outputRange: .data, exposureStops: 1,
        adaptation: .bradford)
    let bradfordProject = ProjectManifest(settings: bradfordSettings, cubeSize: 33, domain: .unit)
    let bradfordBytes = try ProjectCodec.encode(bradfordProject, catalog: catalog)
    guard try ProjectCodec.decode(bradfordBytes, catalog: catalog) == bradfordProject,
          String(decoding: bradfordBytes, as: UTF8.self).contains("\"adaptation\":\"bradford\"") else {
        throw Failure.mismatch("Bradford project roundtrip")
    }
    do {
        _ = try ProjectCodec.decode(mutated(bradfordBytes, ["settings", "adaptation"], "unknown"),
                                    catalog: catalog)
        throw Failure.mismatch("unknown adaptation accepted")
    } catch ProjectError.malformed {}
    for exposure in [0.1, 0.18.nextUp, -0.0, -1e-300, 100.00000000000001] {
        let variant = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: exposure
        )
        let sample = ProjectManifest(settings: variant, cubeSize: 17, domain: .unit)
        let result = try ProjectCodec.decode(ProjectCodec.encode(sample, catalog: catalog), catalog: catalog)
        guard result.settings.exposureStops.bitPattern == exposure.bitPattern else {
            throw Failure.mismatch("Double bit pattern \(exposure)")
        }
    }
    do {
        _ = try ProjectCodec.decode(mutated(encoded, ["schemaVersion"], 99), catalog: catalog)
        throw Failure.mismatch("future schema accepted")
    } catch ProjectError.unsupportedSchema(99) {}
    do {
        _ = try ProjectCodec.decode(mutated(encoded, ["futureField"], 1), catalog: catalog)
        throw Failure.mismatch("unknown field silently lost")
    } catch ProjectError.unknownField("futureField") {}
    do {
        _ = try ProjectCodec.decode(mutated(encoded, ["settings", "futureSetting"], 1), catalog: catalog)
        throw Failure.mismatch("unknown setting silently lost")
    } catch ProjectError.unknownField("settings.futureSetting") {}
    do {
        _ = try ProjectCodec.decode(mutated(encoded, ["settings", "inputTransfer"], "missing.v1"), catalog: catalog)
        throw Failure.mismatch("unknown algorithm accepted")
    } catch ProjectError.unknownAlgorithm("missing.v1") {}
    do {
        let withAsset = ProjectManifest(settings: settings, cubeSize: 33, domain: domain,
            assetHashes: ["imports/user.cube": "0123456789abcdef"])
        _ = try ProjectCodec.encode(withAsset, catalog: catalog)
        throw Failure.mismatch("invalid asset metadata accepted")
    } catch ProjectError.invalidAssetPath(_) {}

    let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("lutcalc-project-check-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: testRoot) }
    let bradfordURL = testRoot.appendingPathComponent("bradford.lutcalc")
    try ProjectStore.saveNew(bradfordProject, at: bradfordURL, catalog: catalog)
    guard try ProjectStore.open(at: bradfordURL, catalog: catalog) == bradfordProject else {
        throw Failure.mismatch("Bradford package save/open")
    }
    let originalURL = testRoot.appendingPathComponent("one.lutcalc")
    try ProjectStore.saveNew(first, at: originalURL, catalog: catalog)
    let originalBytes = try Data(contentsOf: originalURL.appendingPathComponent("manifest.json"))
    do {
        try ProjectStore.saveNew(first, at: originalURL, catalog: catalog)
        throw Failure.mismatch("overwrite accepted")
    } catch ProjectError.targetExists {}
    guard try Data(contentsOf: originalURL.appendingPathComponent("manifest.json")) == originalBytes else {
        throw Failure.mismatch("existing project modified")
    }
    let movedURL = testRoot.appendingPathComponent("moved.lutcalc")
    try FileManager.default.moveItem(at: originalURL, to: movedURL)
    guard try ProjectStore.open(at: movedURL, catalog: catalog).id == first.id else {
        throw Failure.mismatch("moved project failed")
    }
    let revisedSettings = TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .video, outputRange: .data,
        exposureStops: 0.18000000000000002.nextUp, rangeBitDepth: 12
    )
    let revised = ProjectManifest(id: first.id, settings: revisedSettings, cubeSize: 17, domain: .unit)
    try ProjectStore.saveExisting(revised, replacing: first, at: movedURL, catalog: catalog)
    guard try ProjectStore.open(at: movedURL, catalog: catalog) == revised,
          try ProjectStore.open(at: movedURL, catalog: catalog).settings.exposureStops.bitPattern == revisedSettings.exposureStops.bitPattern else {
        throw Failure.mismatch("existing project update")
    }
    let revisedBytes = try Data(contentsOf: movedURL.appendingPathComponent("manifest.json"))
    do {
        try ProjectStore.saveExisting(revised, replacing: first, at: movedURL, catalog: catalog)
        throw Failure.mismatch("stale project save accepted")
    } catch ProjectError.concurrentModification {}
    let wrongIdentity = ProjectManifest(settings: revisedSettings, cubeSize: 17, domain: .unit)
    do {
        try ProjectStore.saveExisting(wrongIdentity, replacing: revised, at: movedURL, catalog: catalog)
        throw Failure.mismatch("project identity changed")
    } catch ProjectError.projectIdentityMismatch {}
    guard try Data(contentsOf: movedURL.appendingPathComponent("manifest.json")) == revisedBytes else {
        throw Failure.mismatch("rejected project save changed bytes")
    }
    let second = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
    let secondURL = testRoot.appendingPathComponent("two.lutcalc")
    try ProjectStore.saveNew(second, at: secondURL, catalog: catalog)
    guard second.id != first.id,
          try ProjectStore.open(at: secondURL, catalog: catalog).cubeSize == 17,
          try ProjectStore.open(at: movedURL, catalog: catalog).cubeSize == 17 else {
        throw Failure.mismatch("multi-document isolation")
    }
    let sourceAsset = testRoot.appendingPathComponent("user.cube")
    try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: sourceAsset)
    let expectedHash = "71a4b822c702424a0d1d77d02abad109f0bc5ee5652b0a60c15656f58691fdd8"
    guard try ProjectAssets.sha256(of: sourceAsset) == expectedHash else {
        throw Failure.mismatch("asset hash reference")
    }
    let assetPath = "Resources/user.cube"
    let withAsset = ProjectManifest(settings: settings, cubeSize: 33, domain: domain,
        assetHashes: [assetPath: expectedHash])
    let assetURL = testRoot.appendingPathComponent("asset.lutcalc")
    try ProjectStore.saveNew(withAsset, at: assetURL, catalog: catalog, assetSources: [assetPath: sourceAsset])
    try FileManager.default.removeItem(at: sourceAsset)
    let movedAssetURL = testRoot.appendingPathComponent("asset-moved.lutcalc")
    try FileManager.default.moveItem(at: assetURL, to: movedAssetURL)
    guard try ProjectStore.open(at: movedAssetURL, catalog: catalog).assetHashes[assetPath] == expectedHash else {
        throw Failure.mismatch("self-contained asset move")
    }
    let revisedAsset = ProjectManifest(id: withAsset.id, settings: revisedSettings, cubeSize: 17,
        domain: .unit, assetHashes: [assetPath: expectedHash])
    try ProjectStore.saveExisting(revisedAsset, replacing: withAsset, at: movedAssetURL, catalog: catalog)
    guard try ProjectStore.open(at: movedAssetURL, catalog: catalog) == revisedAsset else {
        throw Failure.mismatch("existing project asset update")
    }
    let embedded = movedAssetURL.appendingPathComponent(assetPath)
    let revisedAssetBytes = try Data(contentsOf: movedAssetURL.appendingPathComponent("manifest.json"))
    let badAssetRevision = ProjectManifest(id: withAsset.id, settings: settings, cubeSize: 33,
        domain: domain, assetHashes: [assetPath: String(repeating: "0", count: 64)])
    do {
        try ProjectStore.saveExisting(badAssetRevision, replacing: revisedAsset, at: movedAssetURL,
            catalog: catalog, assetSources: [assetPath: embedded])
        throw Failure.mismatch("failed update accepted")
    } catch ProjectError.assetHashMismatch(assetPath) {}
    let projectDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: testRoot.path)
    guard try Data(contentsOf: movedAssetURL.appendingPathComponent("manifest.json")) == revisedAssetBytes,
          try ProjectStore.open(at: movedAssetURL, catalog: catalog) == revisedAsset,
          !projectDirectoryContents.contains(where: { $0.hasPrefix(".lutcalc-") }) else {
        throw Failure.mismatch("failed update damaged project or left staging")
    }
    guard try Data(contentsOf: embedded) == Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8) else {
        throw Failure.mismatch("embedded bytes")
    }
    try Data("changed".utf8).write(to: embedded)
    do {
        _ = try ProjectStore.open(at: movedAssetURL, catalog: catalog)
        throw Failure.mismatch("tampered asset accepted")
    } catch ProjectError.assetHashMismatch(assetPath) {}
    let absentTarget = testRoot.appendingPathComponent("missing-source.lutcalc")
    do {
        try ProjectStore.saveNew(withAsset, at: absentTarget, catalog: catalog, assetSources: [:])
        throw Failure.mismatch("missing asset source accepted")
    } catch ProjectError.missingAsset(assetPath) {}
    guard !FileManager.default.fileExists(atPath: absentTarget.path) else {
        throw Failure.mismatch("failed save left target")
    }
    let traversal = ProjectManifest(settings: settings, cubeSize: 33, domain: domain,
        assetHashes: ["Resources/../escape.cube": expectedHash])
    do {
        _ = try ProjectCodec.encode(traversal, catalog: catalog)
        throw Failure.mismatch("path traversal accepted")
    } catch ProjectError.invalidAssetPath(_) {}
    let wrongHashURL = testRoot.appendingPathComponent("wrong-hash.lutcalc")
    try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: sourceAsset)
    let wrongHash = ProjectManifest(settings: settings, cubeSize: 33, domain: domain,
        assetHashes: [assetPath: String(repeating: "0", count: 64)])
    do {
        try ProjectStore.saveNew(wrongHash, at: wrongHashURL, catalog: catalog, assetSources: [assetPath: sourceAsset])
        throw Failure.mismatch("wrong source hash accepted")
    } catch ProjectError.assetHashMismatch(assetPath) {}
    guard !FileManager.default.fileExists(atPath: wrongHashURL.path) else {
        throw Failure.mismatch("hash failure left target")
    }
    try FileManager.default.removeItem(at: embedded)
    try FileManager.default.createSymbolicLink(at: embedded, withDestinationURL: sourceAsset)
    do {
        _ = try ProjectStore.open(at: movedAssetURL, catalog: catalog)
        throw Failure.mismatch("resource symlink accepted")
    } catch ProjectError.invalidPackage {}
    print("H12 项目契约通过：Double 位精确、Bradford 设置读写、未知项拒绝、移动/双文档、拒绝覆盖、已有项目事务修改、过期编辑拒绝、用户资源哈希与篡改/缺失拒绝")
} catch {
    fputs("LUTProjectChecks: \(error)\n", stderr)
    exit(1)
}
