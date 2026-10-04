import Foundation
import SwiftUI
import UniformTypeIdentifiers
import LUTCore
import LUTFormats
import LUTCatalog
import LUTJobs
import LUTProject
import LUTAnalysis

public enum LogCSceneSlot: Sendable { case input, output }
public enum LogCSceneEditError: Error, Sendable { case staleRevision }

public struct LUTProjectDocument: FileDocument {
    public static let projectType = UTType(exportedAs: "org.lutcalc.project", conformingTo: .package)
    public static var readableContentTypes: [UTType] { [projectType] }
    public static var writableContentTypes: [UTType] { [projectType] }
    public static let maxManifestBytes = ProjectCodec.maxManifestBytes
    public static let maxTotalAssetBytes = 256 * 1024 * 1024

    private var editing: ProjectEditingSession
    public var manifest: ProjectManifest { editing.current }
    public var canUndo: Bool { editing.canUndo }
    public var canRedo: Bool { editing.canRedo }
    public var revision: UInt64 { editing.revision }
    public var assetContents: [String: Data]

    public init() {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let manifest = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        do {
            editing = try ProjectEditingSession(new: manifest, catalog: AlgorithmCatalog.builtIn())
        } catch {
            preconditionFailure("Built-in default project is invalid: \(error)")
        }
        assetContents = [:]
    }

    public init(new manifest: ProjectManifest, assetContents: [String: Data] = [:]) throws {
        try Self.validate(manifest, assetContents: assetContents)
        editing = try ProjectEditingSession(new: manifest, catalog: AlgorithmCatalog.builtIn())
        self.assetContents = assetContents
    }

    public init(fileWrapper: FileWrapper) throws {
        guard fileWrapper.isDirectory, let root = fileWrapper.fileWrappers,
              Set(root.keys).isSubset(of: ["manifest.json", "Resources"]),
              let manifestFile = root["manifest.json"], manifestFile.isRegularFile,
              let manifestBytes = manifestFile.regularFileContents else {
            throw ProjectError.invalidPackage
        }
        guard manifestBytes.count <= Self.maxManifestBytes else { throw ProjectError.manifestSizeLimit }
        let manifest = try ProjectCodec.decode(manifestBytes, catalog: AlgorithmCatalog.builtIn())
        var assets: [String: Data] = [:]
        var totalAssetBytes = 0
        if manifest.assetHashes.isEmpty {
            guard root["Resources"] == nil else { throw ProjectError.invalidPackage }
        } else {
            guard let resourceDirectory = root["Resources"], resourceDirectory.isDirectory,
                  let resources = resourceDirectory.fileWrappers else {
                throw ProjectError.invalidPackage
            }
            let expected = Set(manifest.assetHashes.keys.map { String($0.dropFirst("Resources/".count)) })
            guard Set(resources.keys) == expected else { throw ProjectError.invalidPackage }
            for (path, hash) in manifest.assetHashes {
                let name = String(path.dropFirst("Resources/".count))
                guard let resource = resources[name], resource.isRegularFile,
                      let data = resource.regularFileContents else {
                    throw ProjectError.invalidPackage
                }
                guard data.count <= ProjectAssets.maxAssetBytes else { throw ProjectError.assetSizeLimit }
                let (newTotal, overflow) = totalAssetBytes.addingReportingOverflow(data.count)
                guard !overflow, newTotal <= Self.maxTotalAssetBytes else {
                    throw ProjectError.assetSizeLimit
                }
                totalAssetBytes = newTotal
                guard ProjectAssets.sha256(of: data) == hash else {
                    throw ProjectError.assetHashMismatch(path)
                }
                assets[path] = data
            }
        }
        try Self.validate(manifest, assetContents: assets)
        editing = try ProjectEditingSession(new: manifest, catalog: AlgorithmCatalog.builtIn())
        assetContents = assets
    }

    public init(configuration: ReadConfiguration) throws {
        try self.init(fileWrapper: configuration.file)
    }

    public mutating func apply(_ manifest: ProjectManifest) throws {
        try Self.validate(manifest, assetContents: assetContents)
        try editing.apply(manifest)
    }

    public mutating func applyExposureBatchPreset(_ preset: ExposureBatchPreset?) throws {
        try apply(manifest.withExposureBatchPreset(preset))
    }

    /// Enables or disables a stored independent 1D input curve without changing
    /// its original bytes. The normal manifest history supports undo/redo.
    public mutating func applyInputShaper(_ settings: ProjectInputShaperSettings?) throws {
        let old = manifest
        try apply(ProjectManifest(id: old.id, settings: old.settings, cubeSize: old.cubeSize,
            domain: old.domain, assetHashes: old.assetHashes, assetRoles: old.assetRoles,
            userLUTPostStage: old.userLUTPostStage, userLUTInputInverse: old.userLUTInputInverse,
            exposureBatchPreset: old.exposureBatchPreset, inputShaper: settings))
    }

    /// Stores only an explicitly imported curve, never a bundled or generated
    /// replacement table. A shaper and post LUT have separate asset roles.
    @discardableResult
    public mutating func storeImportedInputShaper(_ imported: ImportedUserLUT) throws -> String {
        guard !manifest.assetRoles.values.contains(.inputShaper) else {
            throw UserLUTImportError.projectAlreadyHasAsset
        }
        guard let bytes = imported.originalBytes else { throw UserLUTImportError.missingOriginalBytes }
        guard bytes.count <= ProjectAssets.maxAssetBytes else { throw ProjectError.assetSizeLimit }
        let extensionName = imported.format == .assimilate ? "lut" : imported.format.rawValue
        let path = "Resources/shaper-\(UUID().uuidString.lowercased()).\(extensionName)"
        let parsed = try NativeUserLUTLoader.parse(bytes, named: path)
        guard parsed.format == imported.format, parsed.lut == imported.lut else {
            throw UserLUTImportError.sourceContentMismatch
        }
        guard parsed.lut.dimension == .one, parsed.lut.shaper == nil else {
            throw ProjectError.invalidInputShaper
        }
        let old = manifest
        var hashes = old.assetHashes, roles = old.assetRoles, contents = assetContents
        hashes[path] = ProjectAssets.sha256(of: bytes)
        roles[path] = .inputShaper
        contents[path] = bytes
        let next = ProjectManifest(id: old.id, settings: old.settings, cubeSize: old.cubeSize,
            domain: old.domain, assetHashes: hashes, assetRoles: roles,
            userLUTPostStage: old.userLUTPostStage, userLUTInputInverse: old.userLUTInputInverse,
            exposureBatchPreset: old.exposureBatchPreset,
            inputShaper: ProjectInputShaperSettings(assetPath: path))
        try Self.validate(next, assetContents: contents)
        try editing.replaceForAssetChange(next)
        assetContents = contents
        return path
    }

    private static func readInputShaper(_ manifest: ProjectManifest,
                                       assetContents: [String: Data]) throws -> CubeShaper? {
        guard let settings = manifest.inputShaper else { return nil }
        guard let bytes = assetContents[settings.assetPath] else {
            throw ProjectError.missingAsset(settings.assetPath)
        }
        guard ProjectAssets.sha256(of: bytes) == manifest.assetHashes[settings.assetPath] else {
            throw ProjectError.assetHashMismatch(settings.assetPath)
        }
        let lut = try NativeUserLUTLoader.parse(bytes, named: settings.assetPath).lut
        guard lut.dimension == .one, lut.shaper == nil else { throw ProjectError.invalidInputShaper }
        return try CubeShaper(size: lut.size, domain: lut.domain, samples: lut.samples)
    }

    public mutating func applyPreset(_ preset: PresetDescriptor) throws {
        let old = manifest
        try apply(ProjectManifest(id: old.id, settings: preset.settings,
                                  cubeSize: old.cubeSize, domain: old.domain,
                                  assetHashes: old.assetHashes, assetRoles: old.assetRoles,
                                  userLUTPostStage: old.userLUTPostStage,
                                  userLUTInputInverse: old.userLUTInputInverse,
                                  exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper))
    }

    public mutating func applyLogCScene(_ payload: ARRILogCSceneSettings, slot: LogCSceneSlot,
                                      expectedRevision: UInt64) throws {
        guard revision == expectedRevision else { throw LogCSceneEditError.staleRevision }
        let old = manifest
        let settings: TransformSettings
        switch slot {
        case .input:
            settings = old.settings.withInput(transfer: payload.algorithm.transferID, space: old.settings.inputSpace)
                .withInputLogC(payload)
        case .output:
            settings = old.settings.withOutput(transfer: payload.algorithm.transferID, space: old.settings.outputSpace)
                .withOutputLogC(payload)
        }
        try apply(ProjectManifest(id: old.id, settings: settings, cubeSize: old.cubeSize, domain: old.domain,
            assetHashes: old.assetHashes, assetRoles: old.assetRoles, userLUTPostStage: old.userLUTPostStage,
            userLUTInputInverse: old.userLUTInputInverse,
            exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper))
    }

    public enum CameraEditError:Error,Equatable {case staleRevision,missingCamera}

    public mutating func applyCameraSelection(profileID:String,inputPolicy:CameraInputPolicy,expectedRevision:UInt64)throws {
        guard revision == expectedRevision else {throw CameraEditError.staleRevision}
        let camera=try CameraExposureSettings.selecting(profileID:profileID,inputPolicy:inputPolicy)
        let settings=try CameraPresetResolver.applying(camera,to:manifest.settings)
        try applyCameraSettings(settings)
    }
    public mutating func applyCameraExposure(_ camera:CameraExposureSettings,expectedRevision:UInt64)throws {
        guard revision == expectedRevision else {throw CameraEditError.staleRevision}
        // ISO/stop edits retain the explicit current input; only camera
        // selection invokes the chosen default-input policy.
        try applyCameraSettings(camera.applyingExposure(to:manifest.settings))
    }
    public mutating func applyCameraRecordedISO(_ iso:Int,expectedRevision:UInt64)throws {
        guard revision == expectedRevision else {throw CameraEditError.staleRevision}
        guard let camera=manifest.settings.cameraExposure else {throw CameraEditError.missingCamera}
        try applyCameraExposure(camera.changingRecordedISO(iso),expectedRevision:expectedRevision)
    }
    public mutating func applyCameraStopCorrection(_ stops:Double,expectedRevision:UInt64)throws {
        guard revision == expectedRevision else {throw CameraEditError.staleRevision}
        guard let camera=manifest.settings.cameraExposure else {throw CameraEditError.missingCamera}
        try applyCameraExposure(camera.changingStopCorrection(stops),expectedRevision:expectedRevision)
    }
    private mutating func applyCameraSettings(_ settings:TransformSettings)throws {
        let old=manifest
        try apply(ProjectManifest(id:old.id,settings:settings,cubeSize:old.cubeSize,domain:old.domain,
            assetHashes:old.assetHashes,assetRoles:old.assetRoles,userLUTPostStage:old.userLUTPostStage,
            userLUTInputInverse:old.userLUTInputInverse,
            exposureBatchPreset:old.exposureBatchPreset, inputShaper: old.inputShaper))
    }

    public mutating func applyParameterizedGamma(_ draft: ParameterizedGammaDraft,
                                                 slot: ParameterizedGammaSlot,
                                                 expectedRevision: UInt64) throws {
        guard revision == expectedRevision else { throw ParameterizedGammaDraftError.staleRevision }
        let gamma = try draft.makeSettings()
        let old = manifest
        let settings = old.settings
        let updatedSettings = TransformSettings(
            inputTransfer: slot == .input ? .parameterizedGamma : settings.inputTransfer,
            outputTransfer: slot == .output ? .parameterizedGamma : settings.outputTransfer,
            inputSpace: settings.inputSpace, outputSpace: settings.outputSpace,
            inputRange: settings.inputRange, outputRange: settings.outputRange,
            exposureStops: settings.exposureStops, rangeBitDepth: settings.rangeBitDepth,
            adaptation: settings.adaptation,
            inputGamma: slot == .input ? gamma : settings.inputGamma,
            outputGamma: slot == .output ? gamma : settings.outputGamma,
            ascCDL: settings.ascCDL, sdrSaturation: settings.sdrSaturation, multitone: settings.multitone, blackGamma: settings.blackGamma,
            blackHighlight: settings.blackHighlight?.rebasedForChanges(outputChanged: slot == .output && (settings.outputTransfer != .parameterizedGamma || settings.outputGamma != gamma)), knee:settings.knee,highlightGamut:settings.highlightGamut,gamutLimiter:settings.gamutLimiter,outputCodeUnits:settings.outputCodeUnits,displayConversion:settings.displayConversion,falseColour:settings.falseColour,finalOutput:settings.finalOutput,
            inputLogC:slot == .input ? nil : settings.inputLogC,outputLogC:slot == .output ? nil : settings.outputLogC,
            cameraExposure:settings.cameraExposure, hlgOOTF: settings.hlgOOTF)
        try apply(ProjectManifest(id: old.id, settings: updatedSettings,
                                  cubeSize: old.cubeSize, domain: old.domain,
                                  assetHashes: old.assetHashes, assetRoles: old.assetRoles,
                                  userLUTPostStage: old.userLUTPostStage,
                                  userLUTInputInverse: old.userLUTInputInverse,
                                  exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper))
    }

    public mutating func applyUserLUTPostStage(_ settings: UserLUTPostStageSettings?) throws {
        let old = manifest
        var candidate = self
        try candidate.apply(ProjectManifest(id: old.id, settings: old.settings,
            cubeSize: old.cubeSize, domain: old.domain, assetHashes: old.assetHashes,
            assetRoles: old.assetRoles, userLUTPostStage: settings,
            userLUTInputInverse: old.userLUTInputInverse,
            exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper))
        if settings != nil { _ = try candidate.makeGenerationRequest() }
        self = candidate
    }

    /// 为已存储的用户 LUT 声明严格单值 1D 输入反求。
    public mutating func applyUserLUTInputInverse(_ settings: UserLUTInputInverseSettings?) throws {
        let old = manifest
        var candidate = self
        try candidate.apply(ProjectManifest(id: old.id, settings: old.settings,
            cubeSize: old.cubeSize, domain: old.domain, assetHashes: old.assetHashes,
            assetRoles: old.assetRoles, userLUTPostStage: old.userLUTPostStage,
            userLUTInputInverse: settings, exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper))
        if let settings {
            guard old.userLUTAssetPaths == [settings.assetPath],
                  settings.interpolation == .tricubicLegacyV1 else {
                throw ProjectError.invalidAssetRoles
            }
            _ = try candidate.makeGenerationRequest()
        }
        self = candidate
    }

    public var storedUserLUTPaths: [String] {
        manifest.userLUTAssetPaths
    }

    public struct StoredUserLUTExport: FileDocument, Sendable {
        public static let readableContentTypes: [UTType] = [.data]
        public static let writableContentTypes: [UTType] = [.data]
        public let suggestedFilename: String
        public let bytes: Data

        public init(suggestedFilename: String, bytes: Data) {
            self.suggestedFilename = suggestedFilename
            self.bytes = bytes
        }

        public func makeFileWrapper() -> FileWrapper {
            FileWrapper(regularFileWithContents: bytes)
        }

        public init(configuration: ReadConfiguration) throws {
            suggestedFilename = "exported-lut"
            bytes = configuration.file.regularFileContents ?? Data()
        }

        public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            makeFileWrapper()
        }
    }

    public func makeStoredUserLUTExport() throws -> StoredUserLUTExport {
        guard let path = storedUserLUTPaths.first else { throw UserLUTImportError.noImportedLUT }
        guard let bytes = assetContents[path],
              let hash = manifest.assetHashes[path],
              ProjectAssets.sha256(of: bytes) == hash else {
            throw ProjectError.assetHashMismatch(path)
        }
        let filename = String(path.dropFirst("Resources/".count))
        return StoredUserLUTExport(suggestedFilename: filename, bytes: bytes)
    }

    @discardableResult
    public mutating func storeImportedUserLUT(_ imported: ImportedUserLUT) throws -> String {
        guard storedUserLUTPaths.isEmpty else { throw UserLUTImportError.projectAlreadyHasAsset }
        guard let bytes = imported.originalBytes else { throw UserLUTImportError.missingOriginalBytes }
        guard bytes.count <= ProjectAssets.maxAssetBytes else { throw ProjectError.assetSizeLimit }
        let extensionName = imported.format.rawValue == "assimilate" ? "lut" : imported.format.rawValue
        let path = "Resources/user-\(UUID().uuidString.lowercased()).\(extensionName)"
        let checked = try NativeUserLUTLoader.parse(bytes, named: path)
        guard checked.format == imported.format, checked.lut == imported.lut else {
            throw UserLUTImportError.sourceContentMismatch
        }
        let hash = ProjectAssets.sha256(of: bytes)
        let old = manifest
        var hashes = old.assetHashes
        hashes[path] = hash
        var roles = old.assetRoles
        roles[path] = .userLUT
        var contents = assetContents
        contents[path] = bytes
        let updated = ProjectManifest(id: old.id, settings: old.settings,
                                      cubeSize: old.cubeSize, domain: old.domain,
                                      assetHashes: hashes, assetRoles: roles,
                                      userLUTPostStage: old.userLUTPostStage,
                                      userLUTInputInverse: old.userLUTInputInverse,
                                      exposureBatchPreset: old.exposureBatchPreset, inputShaper: old.inputShaper)
        try Self.validate(updated, assetContents: contents)
        try editing.replaceForAssetChange(updated)
        assetContents = contents
        return path
    }

    public func inspectStoredUserLUT(at path: String) throws -> ImportedUserLUT {
        guard manifest.assetRoles[path] == .userLUT ||
              manifest.assetRoles[path] == .legacyUserLUT else {
            throw UserLUTImportError.notStoredUserLUT
        }
        guard let bytes = assetContents[path] else { throw ProjectError.missingAsset(path) }
        guard let hash = manifest.assetHashes[path], ProjectAssets.sha256(of: bytes) == hash else {
            throw ProjectError.assetHashMismatch(path)
        }
        return try NativeUserLUTLoader.parse(bytes, named: path)
    }

    @discardableResult
    public mutating func undo() -> Bool { editing.undo() }

    @discardableResult
    public mutating func redo() -> Bool { editing.redo() }

    /// Captures batch requests from the same immutable project and user assets.
    /// This backend entry point does not edit the document or open a file panel.
    public func makeExposureBatchRequest(settings:ExposureBatchSettings,directory:URL,basename:String,
                                         format:FileLUTFormat,allowOverwrite:Bool = false,
                                         threeDLFlavor:ThreeDLFlavor = .flame)throws->ExposureBatchRequest {
        try ExposureBatchRequest(base:makeGenerationRequest(),settings:settings,directory:directory,
                                 basename:basename,format:format,allowOverwrite:allowOverwrite,threeDLFlavor:threeDLFlavor)
    }

    public func makeStoredExposureBatchRequest(directory: URL, allowOverwrite: Bool = false) throws -> ExposureBatchRequest {
        guard let preset = manifest.exposureBatchPreset else { throw ProjectError.missingExposureBatchPreset }
        return try ExposureBatchRequest(base: makeGenerationRequest(blockNodes: preset.blockNodes, workerCount: preset.workerCount),
            settings: preset.sequence, directory: directory, basename: preset.basename, format: preset.format,
            allowOverwrite: allowOverwrite, threeDLFlavor: preset.threeDLFlavor)
    }

    public func makeGenerationRequest(blockNodes: Int = 4096, workerCount: Int = 2) throws -> LUTGenerationRequest {
        let postLUT: CubeLUT?
        if let path = manifest.userLUTAssetPaths.first {
            let imported = try inspectStoredUserLUT(at: path)
            if manifest.userLUTPostStage == nil {
                guard imported.lut.dimension == .one, imported.lut.shaper == nil,
                  imported.lut.domain.min.r.bitPattern == 0,
                  imported.lut.domain.min.g.bitPattern == 0,
                  imported.lut.domain.min.b.bitPattern == 0,
                  imported.lut.domain.max.r.bitPattern == 1.0.bitPattern,
                  imported.lut.domain.max.g.bitPattern == 1.0.bitPattern,
                  imported.lut.domain.max.b.bitPattern == 1.0.bitPattern else {
                throw EditorSessionError.userLUTRequiresUnitOneDimensional
                }
            }
            postLUT = imported.lut
        } else {
            postLUT = nil
        }
        let inputTransferInverse: ImportedLUTInversePlan?
        if let inverseSettings = manifest.userLUTInputInverse {
            guard manifest.userLUTAssetPaths == [inverseSettings.assetPath] else {
                throw ProjectError.invalidAssetRoles
            }
            let imported = try inspectStoredUserLUT(at: inverseSettings.assetPath)
            inputTransferInverse = try ImportedLUTInversePlan(lut: imported.lut,
                                                               analysisFile: imported.analysis,
                                                               interpolation: inverseSettings.interpolation)
        } else {
            inputTransferInverse = nil
        }
        return try LUTGenerationRequest(plan: TransformPlan(settings: manifest.settings),
                                        size: manifest.cubeSize, domain: manifest.domain,
                                        blockNodes: blockNodes, workerCount: workerCount,
                                        postLUT: postLUT, postLUTSettings: manifest.userLUTPostStage,
                                        inputShaper: try Self.readInputShaper(manifest, assetContents: assetContents),
                                        inputTransferInverse: inputTransferInverse)
    }

    public func makeFileWrapper() throws -> FileWrapper {
        try Self.validate(manifest, assetContents: assetContents)
        let manifestData = try ProjectCodec.encode(manifest, catalog: AlgorithmCatalog.builtIn())
        var root: [String: FileWrapper] = [
            "manifest.json": FileWrapper(regularFileWithContents: manifestData)
        ]
        if !assetContents.isEmpty {
            var resources: [String: FileWrapper] = [:]
            for (path, data) in assetContents {
                resources[String(path.dropFirst("Resources/".count))] = FileWrapper(regularFileWithContents: data)
            }
            root["Resources"] = FileWrapper(directoryWithFileWrappers: resources)
        }
        return FileWrapper(directoryWithFileWrappers: root)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try makeFileWrapper()
    }

    private static func validate(_ manifest: ProjectManifest,
                                 assetContents: [String: Data]) throws {
        let bytes = try ProjectCodec.encode(manifest, catalog: AlgorithmCatalog.builtIn())
        guard bytes.count <= maxManifestBytes else { throw ProjectError.manifestSizeLimit }
        if let missing = Set(manifest.assetHashes.keys).subtracting(assetContents.keys).sorted().first {
            throw ProjectError.missingAsset(missing)
        }
        if let extra = Set(assetContents.keys).subtracting(manifest.assetHashes.keys).sorted().first {
            throw ProjectError.unexpectedAsset(extra)
        }
        _ = try readInputShaper(manifest, assetContents: assetContents)
        var totalAssetBytes = 0
        for (path, data) in assetContents {
            guard data.count <= ProjectAssets.maxAssetBytes else { throw ProjectError.assetSizeLimit }
            let (newTotal, overflow) = totalAssetBytes.addingReportingOverflow(data.count)
            guard !overflow, newTotal <= maxTotalAssetBytes else { throw ProjectError.assetSizeLimit }
            totalAssetBytes = newTotal
            guard ProjectAssets.sha256(of: data) == manifest.assetHashes[path] else {
                throw ProjectError.assetHashMismatch(path)
            }
        }
    }
}
