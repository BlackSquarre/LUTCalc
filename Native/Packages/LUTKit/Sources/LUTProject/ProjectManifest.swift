import Foundation
import CryptoKit
import LUTCore
import LUTFormats
import LUTCatalog

public enum ProjectError: Error, Equatable, Sendable {
    case malformed
    case unsupportedSchema(Int)
    case unsupportedEngine(String)
    case unsupportedCatalog(String)
    case unknownField(String)
    case duplicateKey(String)
    case unknownAlgorithm(String)
    case algorithmMismatch
    case invalidSettings
    case invalidAssetPath(String)
    case invalidAssetHash(String)
    case invalidAssetRoles
    case missingAsset(String)
    case unexpectedAsset(String)
    case assetHashMismatch(String)
    case assetSizeLimit
    case manifestSizeLimit
    case targetExists
    case invalidPackage
    case concurrentModification
    case projectIdentityMismatch
    case missingExposureBatchPreset
    case invalidInputShaper
}

public enum ProjectAssetRole: String, Codable, Equatable, Sendable {
    case other
    case userLUT
    case legacyUserLUT
    case inputShaper
}

public struct ProjectManifest: Equatable, Codable, Sendable {
    public static let currentSchema = 25
    public static let currentEngine = "native-minimal-v1"
    public static let currentCatalog = "catalog-minimal-v1"

    public let schemaVersion: Int
    public let engineVersion: String
    public let registryVersion: String
    public let id: UUID
    public let algorithmVersions: [String: String]
    public let settings: TransformSettings
    public let cubeSize: Int
    public let domain: LUTDomain
    public let assetHashes: [String: String]
    public let assetRoles: [String: ProjectAssetRole]
    public let userLUTPostStage: UserLUTPostStageSettings?
    public let userLUTInputInverse: UserLUTInputInverseSettings?
    public let exposureBatchPreset: ExposureBatchPreset?
    public let inputShaper: ProjectInputShaperSettings?

    public var userLUTAssetPaths: [String] {
        assetRoles.compactMap { path, role in
            role == .userLUT || role == .legacyUserLUT ? path : nil
        }.sorted()
    }

    public init(id: UUID = UUID(), settings: TransformSettings, cubeSize: Int,
                domain: LUTDomain, assetHashes: [String: String] = [:],
                assetRoles: [String: ProjectAssetRole]? = nil,
                userLUTPostStage: UserLUTPostStageSettings? = nil,
                userLUTInputInverse: UserLUTInputInverseSettings? = nil,
                exposureBatchPreset: ExposureBatchPreset? = nil,
                inputShaper: ProjectInputShaperSettings? = nil) {
        schemaVersion = Self.currentSchema
        engineVersion = Self.currentEngine
        registryVersion = Self.currentCatalog
        self.id = id
        algorithmVersions = Self.algorithmVersions(for: settings,
                                                   exposureBatchPreset: exposureBatchPreset,
                                                   userLUTInputInverse: userLUTInputInverse, inputShaper: inputShaper)
        self.settings = settings
        self.cubeSize = cubeSize
        self.domain = domain
        self.assetHashes = assetHashes
        self.assetRoles = assetRoles ?? assetHashes.mapValues { _ in .other }
        self.userLUTPostStage = userLUTPostStage
        self.userLUTInputInverse = userLUTInputInverse
        self.exposureBatchPreset = exposureBatchPreset
        self.inputShaper = inputShaper
    }

    public func withExposureBatchPreset(_ preset: ExposureBatchPreset?) -> ProjectManifest {
        ProjectManifest(id: id, settings: settings, cubeSize: cubeSize, domain: domain,
            assetHashes: assetHashes, assetRoles: assetRoles, userLUTPostStage: userLUTPostStage,
            userLUTInputInverse: userLUTInputInverse,
            exposureBatchPreset: preset, inputShaper: inputShaper)
    }

    static func algorithmVersions(for settings: TransformSettings,
                                  exposureBatchPreset: ExposureBatchPreset? = nil,
                                  userLUTInputInverse: UserLUTInputInverseSettings? = nil,
                                  inputShaper: ProjectInputShaperSettings? = nil) -> [String: String] {
        var versions = [
            "inputTransfer": settings.inputTransfer.rawValue,
            "outputTransfer": settings.outputTransfer.rawValue,
            "inputSpace": settings.inputSpace.rawValue,
            "outputSpace": settings.outputSpace.rawValue,
        ]
        if let logC = settings.inputLogC { versions["inputLogC"] = logC.algorithm.rawValue }
        if let camera = settings.cameraExposure {
            versions["cameraExposure"] = camera.algorithm
            versions["cameraProfile"] = camera.profileID
            versions["cameraStopSource"] = camera.source.rawValue
            versions["cameraInputPolicy"] = camera.inputPolicy.rawValue
        }
        if let logC = settings.outputLogC { versions["outputLogC"] = logC.algorithm.rawValue }
        if let cdl = settings.ascCDL { versions["ascCDL"] = cdl.algorithm.rawValue }
        if let sat = settings.sdrSaturation { versions["sdrSaturation"] = sat.algorithm.rawValue }
        if let mt = settings.multitone { versions["multitone"] = mt.algorithm.rawValue }
        if let gamma = settings.blackGamma { versions["blackGamma"] = gamma.algorithm.rawValue }
        if let levels = settings.blackHighlight { versions["blackHighlight"] = levels.algorithm.rawValue }
        if let knee = settings.knee { versions["knee"] = knee.algorithm.rawValue }
        if let hg = settings.highlightGamut { versions["highlightGamut"] = hg.algorithm.rawValue }
        if let limiter=settings.gamutLimiter { versions["gamutLimiter"] = limiter.algorithm.rawValue }
        if let display=settings.displayConversion {versions["displayConversion"]=display.algorithm.rawValue}
        if let fc=settings.falseColour {versions["falseColour"]=fc.algorithm.rawValue}
        if let final=settings.finalOutput {versions["finalOutput"]=final.algorithm.rawValue}
        if let hlg=settings.hlgOOTF {versions["hlgOOTF"]=hlg.algorithm.rawValue}
        if settings.requiresOutputCodeUnitIdentity {versions["outputCodeUnits"]=settings.outputCodeUnits.rawValue}
        if let exposureBatchPreset { versions["exposureBatchPreset"] = exposureBatchPreset.algorithm }
        if exposureBatchPreset?.format == .threeDL { versions["exposureBatchFormat"] = ThreeDLFlavor.batchAlgorithm }
        if let userLUTInputInverse { versions["userLUTInputInverse"] = userLUTInputInverse.interpolation.rawValue }
        if let inputShaper { versions["inputShaper"] = inputShaper.algorithm }
        return versions
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, engineVersion, registryVersion, id, algorithmVersions
        case settings, cubeSize, domain, assetHashes, assetRoles
        case userLUTPostStage, userLUTInputInverse, exposureBatchPreset, inputShaper
    }

    private enum OutputCodeUnitMigrationKeys:String,CodingKey {case outputCodeUnits, inputLogC, outputLogC, cameraExposure, hlgOOTF}
    private enum BatchFlavorMigrationKeys:String,CodingKey {case threeDLFlavor}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(Int.self, forKey: .schemaVersion)
        guard (1...Self.currentSchema).contains(schema) else {
            throw ProjectError.unsupportedSchema(schema)
        }
        schemaVersion = Self.currentSchema
        engineVersion = try container.decode(String.self, forKey: .engineVersion)
        registryVersion = try container.decode(String.self, forKey: .registryVersion)
        id = try container.decode(UUID.self, forKey: .id)
        var versions=try container.decode([String:String].self,forKey:.algorithmVersions)
        guard schema >= 16 || (!container.contains(.exposureBatchPreset) && versions["exposureBatchPreset"] == nil) else {
            throw ProjectError.unsupportedSchema(schema)
        }
        exposureBatchPreset = schema >= 16 ? try container.decodeIfPresent(ExposureBatchPreset.self, forKey: .exposureBatchPreset) : nil
        if schema < 24 {
            guard versions["exposureBatchFormat"] == nil else { throw ProjectError.unsupportedSchema(schema) }
            if exposureBatchPreset != nil {
                let fields = try container.nestedContainer(keyedBy: BatchFlavorMigrationKeys.self, forKey: .exposureBatchPreset)
                guard !fields.contains(.threeDLFlavor) else { throw ProjectError.unsupportedSchema(schema) }
            }
            if exposureBatchPreset?.format == .threeDL { versions["exposureBatchFormat"] = ThreeDLFlavor.batchAlgorithm }
        } else if exposureBatchPreset != nil {
            let fields = try container.nestedContainer(keyedBy: BatchFlavorMigrationKeys.self, forKey: .exposureBatchPreset)
            _ = try fields.decode(ThreeDLFlavor.self, forKey: .threeDLFlavor)
        }
        userLUTInputInverse = schema >= 23
            ? try container.decodeIfPresent(UserLUTInputInverseSettings.self, forKey: .userLUTInputInverse) : nil
        if schema < 23 {
            guard !container.contains(.userLUTInputInverse), versions["userLUTInputInverse"] == nil else {
                throw ProjectError.unsupportedSchema(schema)
            }
        }
        inputShaper = schema >= 25 ? try container.decodeIfPresent(ProjectInputShaperSettings.self, forKey: .inputShaper) : nil
        if schema < 25 {
            guard !container.contains(.inputShaper), versions["inputShaper"] == nil else {
                throw ProjectError.unsupportedSchema(schema)
            }
        }
        let decodedSettings=try container.decode(TransformSettings.self,forKey:.settings)
        guard schema >= 20 || !decodedSettings.referencesBMDGen5 else {throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 21 || (!decodedSettings.referencesCanonCLog2 && !decodedSettings.referencesCanonCLog3) else {throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 22 || decodedSettings.hlgOOTF == nil else {throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 18 || !decodedSettings.referencesARRIWideGamut3 else {
            throw ProjectError.unsupportedSchema(schema)
        }
        let unitContainer=try container.nestedContainer(keyedBy:OutputCodeUnitMigrationKeys.self,forKey:.settings)
        if schema < 19 {
            guard !unitContainer.contains(.cameraExposure), decodedSettings.cameraExposure == nil,
                  versions["cameraExposure"] == nil, versions["cameraProfile"] == nil,
                  versions["cameraStopSource"] == nil, versions["cameraInputPolicy"] == nil else {
                throw ProjectError.unsupportedSchema(schema)
            }
        }
        if schema < 17 {
            guard !unitContainer.contains(.inputLogC), !unitContainer.contains(.outputLogC),
                  versions["inputLogC"] == nil, versions["outputLogC"] == nil,
                  !decodedSettings.inputTransfer.requiresLogCSceneSettings,
                  !decodedSettings.outputTransfer.requiresLogCSceneSettings else { throw ProjectError.unsupportedSchema(schema) }
        }
        if schema<12 {
            guard !unitContainer.contains(.outputCodeUnits),versions["outputCodeUnits"] == nil else {
                throw ProjectError.unsupportedSchema(schema)
            }
            // Only the omitted wrapped families need the previous metadata.
            settings=decodedSettings.requiresOutputCodeUnitIdentity ? decodedSettings.withOutputCodeUnits(.partialV1) : decodedSettings
            if settings.requiresOutputCodeUnitIdentity {versions["outputCodeUnits"]=settings.outputCodeUnits.rawValue}
        }else {
            guard !decodedSettings.requiresOutputCodeUnitIdentity || unitContainer.contains(.outputCodeUnits) else {throw ProjectError.malformed}
            settings=decodedSettings
        }
        algorithmVersions=versions
        guard schema >= 4 || settings.ascCDL == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 5 || settings.sdrSaturation == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 6 || settings.multitone == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 7 || settings.blackGamma == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 8 || settings.blackHighlight == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 9 || settings.knee == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 10 || settings.highlightGamut == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 11 || settings.gamutLimiter == nil else { throw ProjectError.unsupportedSchema(schema) }
        guard schema >= 13 || settings.displayConversion == nil else {throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 14 || settings.falseColour == nil else{throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 15 || settings.finalOutput == nil else{throw ProjectError.unsupportedSchema(schema)}
        guard schema >= 22 || settings.hlgOOTF == nil else{throw ProjectError.unsupportedSchema(schema)}
        cubeSize = try container.decode(Int.self, forKey: .cubeSize)
        domain = try container.decode(LUTDomain.self, forKey: .domain)
        assetHashes = try container.decode([String: String].self, forKey: .assetHashes)
        if schema == 1 {
            var roles: [String: ProjectAssetRole] = [:]
            for path in assetHashes.keys {
                roles[path] = Self.isLegacyUserLUTPath(path) ? .legacyUserLUT : .other
            }
            assetRoles = roles
        } else {
            assetRoles = try container.decode([String: ProjectAssetRole].self, forKey: .assetRoles)
        }
        guard schema >= 25 || !assetRoles.values.contains(.inputShaper) else {
            throw ProjectError.unsupportedSchema(schema)
        }
        userLUTPostStage = schema >= 3
            ? try container.decodeIfPresent(UserLUTPostStageSettings.self, forKey: .userLUTPostStage) : nil
    }

    public static func isLegacyUserLUTPath(_ path: String) -> Bool {
        guard path.hasPrefix("Resources/user-") else { return false }
        let filename = String(path.dropFirst("Resources/".count))
        let allowed = Set(["cube", "spi1d", "spi3d", "3dl", "ilut", "olut", "lut", "vlt"])
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        guard allowed.contains(ext) else { return false }
        let stem = String(filename.dropLast(ext.count + 1))
        return stem.hasPrefix("user-") && UUID(uuidString: String(stem.dropFirst(5))) != nil
    }
}

public enum ProjectCodec {
    public static let maxManifestBytes = 8 * 1024 * 1024

    public static func encode(_ document: ProjectManifest, catalog: AlgorithmCatalog) throws -> Data {
        try validate(document, catalog: catalog)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        guard data.count <= maxManifestBytes else { throw ProjectError.manifestSizeLimit }
        return data
    }

    public static func decode(_ data: Data, catalog: AlgorithmCatalog) throws -> ProjectManifest {
        guard data.count <= maxManifestBytes else { throw ProjectError.manifestSizeLimit }
        let raw: Any
        do { raw = try JSONSerialization.jsonObject(with: data) }
        catch { throw ProjectError.malformed }
        guard let root = raw as? [String: Any] else { throw ProjectError.malformed }
        do { try StrictJSONKeyScanner.validate(data) }
        catch StrictJSONKeyError.duplicateKey(let path) { throw ProjectError.duplicateKey(path) }
        catch { throw ProjectError.malformed }
        guard let schema = root["schemaVersion"] as? Int else { throw ProjectError.malformed }
        guard (1...ProjectManifest.currentSchema).contains(schema) else {
            throw ProjectError.unsupportedSchema(schema)
        }
        guard let engine = root["engineVersion"] as? String else { throw ProjectError.malformed }
        guard engine == ProjectManifest.currentEngine else { throw ProjectError.unsupportedEngine(engine) }
        guard let registry = root["registryVersion"] as? String else { throw ProjectError.malformed }
        guard registry == ProjectManifest.currentCatalog else { throw ProjectError.unsupportedCatalog(registry) }
        let allowed = Set(["schemaVersion", "engineVersion", "registryVersion", "id",
                           "algorithmVersions", "settings", "cubeSize", "domain", "assetHashes"])
        var allowedRoot = schema == 1 ? allowed : allowed.union(["assetRoles"])
        if schema >= 3 { allowedRoot.insert("userLUTPostStage") }
        if schema >= 23 { allowedRoot.insert("userLUTInputInverse") }
        if schema >= 25 { allowedRoot.insert("inputShaper") }
        if schema >= 16 { allowedRoot.insert("exposureBatchPreset") }
        try exactKeys(root, allowed: allowedRoot, path: "")
        if let preset = root["exposureBatchPreset"] {
            guard let object = preset as? [String: Any], let sequence = object["sequence"] as? [String: Any] else {
                throw ProjectError.malformed
            }
            var fields:Set<String> = ["algorithm", "sequence", "basename", "format", "blockNodes", "workerCount"]
            if schema >= 24 { fields.insert("threeDLFlavor") }
            try exactKeys(object, allowed: fields, path: "exposureBatchPreset.")
            try exactKeys(sequence, allowed: ["minimumStops", "maximumStops", "subdivisions"], path: "exposureBatchPreset.sequence.")
        }
        if let stage = root["userLUTPostStage"] {
            guard let object = stage as? [String: Any] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["interpolation", "outside"], path: "userLUTPostStage.")
        }
        if let inverse = root["userLUTInputInverse"] {
            guard let object = inverse as? [String: Any] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["assetPath", "interpolation"], path: "userLUTInputInverse.")
        }
        if let shaper = root["inputShaper"] {
            guard let object = shaper as? [String: Any] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["assetPath", "algorithm"], path: "inputShaper.")
        }
        guard let settings = root["settings"] as? [String: Any],
              let domain = root["domain"] as? [String: Any],
              let minimum = domain["min"] as? [String: Any],
              let maximum = domain["max"] as? [String: Any] else { throw ProjectError.malformed }
        var allowedSettings: Set<String> = ["inputTransfer", "outputTransfer", "inputSpace",
            "outputSpace", "inputRange", "outputRange", "exposureStops", "rangeBitDepth",
            "adaptation", "inputGamma", "outputGamma"]
        if schema >= 4 { allowedSettings.insert("ascCDL") }
        if schema >= 5 { allowedSettings.insert("sdrSaturation") }
        if schema >= 6 { allowedSettings.insert("multitone") }
        if schema >= 7 { allowedSettings.insert("blackGamma") }
        if schema >= 8 { allowedSettings.insert("blackHighlight") }
        if schema >= 9 { allowedSettings.insert("knee") }
        if schema >= 10 { allowedSettings.insert("highlightGamut") }
        if schema >= 11 { allowedSettings.insert("gamutLimiter") }
        if schema >= 12 { allowedSettings.insert("outputCodeUnits") }
        if schema >= 13 {allowedSettings.insert("displayConversion")}
        if schema >= 14 {allowedSettings.insert("falseColour")}
        if schema >= 15 {allowedSettings.insert("finalOutput")}
        if schema >= 22 {allowedSettings.insert("hlgOOTF")}
        if schema >= 17 { allowedSettings.formUnion(["inputLogC", "outputLogC"]) }
        if schema >= 19 { allowedSettings.insert("cameraExposure") }
        try exactKeys(settings, allowed: allowedSettings, path: "settings.")
        if let payload = settings["cameraExposure"] {
            guard let object=payload as? [String:Any] else {throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","profileID","recordedISO","stopCorrection","source","inputPolicy"],path:"settings.cameraExposure.")
        }
        for key in ["inputLogC", "outputLogC"] {
            if let payload = settings[key] {
                guard let object = payload as? [String: Any] else { throw ProjectError.malformed }
                try exactKeys(object, allowed: ["algorithm", "exposureIndex"], path: "settings." + key + ".")
            }
        }
        if let final=settings["finalOutput"] {
            guard let object=final as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","mode","clipLegal","minimumCode10","maximumCode10","forceBlackLegal"],path:"settings.finalOutput.")
        }
        if let hlg=settings["hlgOOTF"] {
            guard let object=hlg as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","inputPeakNits","outputPeakNits","inputBlackNits","outputBlackNits","scale","bbcInput","bbcOutput"],path:"settings.hlgOOTF.")
        }
        if let fc=settings["falseColour"] {
            guard let object=fc as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","usage","enabled","doPurple","doBlue","doGreen","doPink","doOrange","doYellow","doRed",
                "blueStopsBelowGray","yellowStopsBelowClip","redStopsAboveGray"],path:"settings.falseColour.")
        }
        if let display=settings["displayConversion"] {
            guard let object=display as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","baseCurve","outputCurve","baseGamut","outputGamut"],path:"settings.displayConversion.")
        }
        if let cdl = settings["ascCDL"] {
            guard let object = cdl as? [String: Any] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["algorithm", "enabled", "slope", "offset", "power", "saturation"],
                          path: "settings.ascCDL.")
            for key in ["slope", "offset", "power"] {
                guard let rgb = object[key] as? [String: Any] else { throw ProjectError.malformed }
                try exactKeys(rgb, allowed: ["r", "g", "b"], path: "settings.ascCDL.\(key).")
            }
        }
        if let sat = settings["sdrSaturation"] {
            guard let object = sat as? [String: Any] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["algorithm", "enabled", "gamma"], path: "settings.sdrSaturation.")
        }
        if let limiter=settings["gamutLimiter"] {
            guard let object=limiter as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","mode","linearStops","postLevel","secondarySpace","protectBoth"],path:"settings.gamutLimiter.")
        }
        if let hg=settings["highlightGamut"] {
            guard let object=hg as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","highlightSpace","transition","lowStops","highStops"],path:"settings.highlightGamut.")
        }
        if let knee=settings["knee"] {
            guard let object=knee as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","startStops","clipStops","clipSlope","smoothness","legal"],path:"settings.knee.")
        }
        if let level=settings["blackHighlight"] {
            guard let object=level as? [String:Any] else{throw ProjectError.malformed}
            try exactKeys(object,allowed:["algorithm","enabled","doBlack","doHigh","blackLevel","blackLock","highReferenceScene","highMap","highLock"],path:"settings.blackHighlight.")
        }
        if let gamma = settings["blackGamma"] {
            guard let object = gamma as? [String:Any] else { throw ProjectError.malformed }
            try exactKeys(object,allowed:["algorithm","enabled","upperStops","featherStops","power"],path:"settings.blackGamma.")
        }
        if let mt = settings["multitone"] {
            guard let object = mt as? [String: Any], let tones = object["tones"] as? [[String: Any]] else { throw ProjectError.malformed }
            try exactKeys(object, allowed: ["algorithm", "enabled", "saturationByStop", "tones"], path: "settings.multitone.")
            for (index,tone) in tones.enumerated() {
                try exactKeys(tone, allowed: ["stop", "hue", "saturation"], path: "settings.multitone.tones[\(index)].")
            }
        }
        for key in ["inputGamma", "outputGamma"] {
            if let gamma = settings[key] {
                guard let gammaObject = gamma as? [String: Any] else { throw ProjectError.malformed }
                try exactKeys(gammaObject,
                              allowed: ["exponent", "linearSlope", "offset", "linearCut", "encodedCut"],
                              path: "settings.\(key).")
            }
        }
        try exactKeys(domain, allowed: ["min", "max"], path: "domain.")
        try exactKeys(minimum, allowed: ["r", "g", "b"], path: "domain.min.")
        try exactKeys(maximum, allowed: ["r", "g", "b"], path: "domain.max.")
        for (kind, lookup) in [
            ("inputTransfer", 0), ("outputTransfer", 0),
            ("inputSpace", 1), ("outputSpace", 1),
        ] {
            guard let id = settings[kind] as? String else { throw ProjectError.malformed }
            let known = lookup == 0 ? catalog.transfer(named: id) != nil : catalog.colorSpace(named: id) != nil
            guard known else { throw ProjectError.unknownAlgorithm(id) }
        }
        let document: ProjectManifest
        do { document = try JSONDecoder().decode(ProjectManifest.self, from: data) }
        catch { throw ProjectError.malformed }
        try validate(document, catalog: catalog)
        return document
    }

    private static func exactKeys(_ object: [String: Any], allowed: Set<String>, path: String) throws {
        for key in object.keys where !allowed.contains(key) {
            throw ProjectError.unknownField(path + key)
        }
    }

    private static func validate(_ document: ProjectManifest, catalog: AlgorithmCatalog) throws {
        guard document.schemaVersion == ProjectManifest.currentSchema else {
            throw ProjectError.unsupportedSchema(document.schemaVersion)
        }
        guard document.engineVersion == ProjectManifest.currentEngine else {
            throw ProjectError.unsupportedEngine(document.engineVersion)
        }
        guard document.registryVersion == ProjectManifest.currentCatalog else {
            throw ProjectError.unsupportedCatalog(document.registryVersion)
        }
        for (path, hash) in document.assetHashes {
            try ProjectAssets.validate(path: path, hash: hash)
        }
        guard Set(document.assetRoles.keys) == Set(document.assetHashes.keys),
              document.assetRoles.values.filter({ $0 == .userLUT || $0 == .legacyUserLUT }).count <= 1,
              document.assetRoles.values.filter({ $0 == .inputShaper }).count <= 1 else {
            throw ProjectError.invalidAssetRoles
        }
        if document.userLUTPostStage != nil, document.userLUTAssetPaths.count != 1 {
            throw ProjectError.invalidAssetRoles
        }
        if let shaper = document.inputShaper {
            guard shaper.algorithm == ProjectInputShaperSettings.algorithm,
                  document.assetRoles[shaper.assetPath] == .inputShaper,
                  document.userLUTInputInverse == nil else { throw ProjectError.invalidInputShaper }
        }
        let settings = document.settings
        do {
            try settings.validateParameterizedTransfers()
        } catch {
            throw ProjectError.invalidSettings
        }
        for id in [settings.inputTransfer.rawValue, settings.outputTransfer.rawValue] {
            guard catalog.transfer(named: id) != nil else { throw ProjectError.unknownAlgorithm(id) }
        }
        for id in [settings.inputSpace.rawValue, settings.outputSpace.rawValue] {
            guard catalog.colorSpace(named: id) != nil else { throw ProjectError.unknownAlgorithm(id) }
        }
        if let hg=settings.highlightGamut {
            guard catalog.colorSpace(named:hg.highlightSpace.rawValue) != nil else {
                throw ProjectError.unknownAlgorithm(hg.highlightSpace.rawValue)
            }
        }
        if let id=settings.gamutLimiter?.secondarySpace?.rawValue,catalog.colorSpace(named:id) == nil {
            throw ProjectError.unknownAlgorithm(id)
        }
        let expected = ProjectManifest.algorithmVersions(for: settings,
                                                         exposureBatchPreset: document.exposureBatchPreset,
                                                         userLUTInputInverse: document.userLUTInputInverse,
                                                         inputShaper: document.inputShaper)
        guard document.algorithmVersions == expected else { throw ProjectError.algorithmMismatch }
        if let inverse = document.userLUTInputInverse {
            guard inverse.interpolation == .tricubicLegacyV1,
                  document.assetRoles[inverse.assetPath] == .userLUT ||
                  document.assetRoles[inverse.assetPath] == .legacyUserLUT,
                  document.userLUTAssetPaths == [inverse.assetPath] else {
                throw ProjectError.invalidAssetRoles
            }
        }
        do {
            _ = try LUTDomain(min: RGB64(document.domain.min.r, document.domain.min.g, document.domain.min.b),
                              max: RGB64(document.domain.max.r, document.domain.max.g, document.domain.max.b))
            _ = try Grid3D(size: document.cubeSize, domain: document.domain)
            _ = try TransformPlan(settings: settings)
            if let preset = document.exposureBatchPreset {
                for stop in preset.sequence.stops { _ = try TransformPlan(settings: settings.withExposureStops(stop)) }
            }
        } catch { throw ProjectError.invalidSettings }
    }
}

public enum ProjectAssets {
    public static let maxAssetBytes = 256 * 1024 * 1024

    public static func validate(path: String, hash: String) throws {
        let pieces = path.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, pieces[0] == "Resources", !pieces[1].isEmpty,
              pieces[1] != ".", pieces[1] != "..", !pieces[1].contains("\\"),
              !pieces[1].contains("\0") else { throw ProjectError.invalidAssetPath(path) }
        guard hash.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw ProjectError.invalidAssetHash(path)
        }
    }

    public static func sha256(of url: URL) throws -> String {
        try readAndHash(source: url, destination: nil)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func copyAndHash(from source: URL, to destination: URL) throws -> String {
        try readAndHash(source: source, destination: destination)
    }

    private static func readAndHash(source: URL, destination: URL?) throws -> String {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var output: FileHandle?
        if let destination {
            guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
                throw ProjectError.invalidPackage
            }
            output = try FileHandle(forWritingTo: destination)
        }
        defer { try? output?.close() }
        var hasher = SHA256()
        var byteCount = 0
        while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            let (newCount, overflow) = byteCount.addingReportingOverflow(chunk.count)
            guard !overflow, newCount <= maxAssetBytes else { throw ProjectError.assetSizeLimit }
            byteCount = newCount
            hasher.update(data: chunk)
            try output?.write(contentsOf: chunk)
        }
        try output?.synchronize()
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum ProjectStore {
    private static let manifestName = "manifest.json"
    /// 默认给仍可能运行的写入者保留的一小时宽限期。
    public static let defaultOrphanRecoveryAge: TimeInterval = 3600

    public static func saveNew(_ document: ProjectManifest, at url: URL,
                               catalog: AlgorithmCatalog,
                               assetSources: [String: URL] = [:]) throws {
        let target = url.standardizedFileURL
        guard !FileManager.default.fileExists(atPath: target.path) else { throw ProjectError.targetExists }
        recoverOrphanedSiblings(in: target.deletingLastPathComponent())
        let bytes = try ProjectCodec.encode(document, catalog: catalog)
        for path in document.assetHashes.keys where assetSources[path] == nil {
            throw ProjectError.missingAsset(path)
        }
        for path in assetSources.keys where document.assetHashes[path] == nil {
            throw ProjectError.unexpectedAsset(path)
        }
        let temporary = target.deletingLastPathComponent()
            .appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }
        if !document.assetHashes.isEmpty {
            let resources = temporary.appendingPathComponent("Resources", isDirectory: true)
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: false)
            for path in document.assetHashes.keys.sorted() {
                guard let source = assetSources[path], let expectedHash = document.assetHashes[path] else {
                    throw ProjectError.missingAsset(path)
                }
                let actualHash = try ProjectAssets.copyAndHash(
                    from: source, to: resources.appendingPathComponent(String(path.dropFirst("Resources/".count))))
                guard actualHash == expectedHash else { throw ProjectError.assetHashMismatch(path) }
            }
        }
        try bytes.write(to: temporary.appendingPathComponent(manifestName), options: .atomic)
        let readback = try Data(contentsOf: temporary.appendingPathComponent(manifestName))
        guard try ProjectCodec.decode(readback, catalog: catalog) == document else {
            throw ProjectError.invalidPackage
        }
        guard !FileManager.default.fileExists(atPath: target.path) else { throw ProjectError.targetExists }
        try FileManager.default.moveItem(at: temporary, to: target)
    }

    public static func saveExisting(_ document: ProjectManifest, replacing expected: ProjectManifest,
                                    at url: URL, catalog: AlgorithmCatalog,
                                    assetSources: [String: URL] = [:],
                                    expectedManifestBytes: Data? = nil) throws {
        try saveExistingImpl(document, replacing: expected, at: url, catalog: catalog,
                             assetSources: assetSources,
                             expectedManifestBytes: expectedManifestBytes,
                             beforeReplacement: {})
    }

    internal static func saveExistingForTesting(
        _ document: ProjectManifest, replacing expected: ProjectManifest,
        at url: URL, catalog: AlgorithmCatalog,
        assetSources: [String: URL] = [:], expectedManifestBytes: Data? = nil,
        beforeReplacement: () throws -> Void
    ) throws {
        try saveExistingImpl(document, replacing: expected, at: url, catalog: catalog,
                             assetSources: assetSources,
                             expectedManifestBytes: expectedManifestBytes,
                             beforeReplacement: beforeReplacement)
    }

    private static func saveExistingImpl(
        _ document: ProjectManifest, replacing expected: ProjectManifest,
        at url: URL, catalog: AlgorithmCatalog,
        assetSources: [String: URL], expectedManifestBytes: Data?,
        beforeReplacement: () throws -> Void
    ) throws {
        guard document.id == expected.id else { throw ProjectError.projectIdentityMismatch }
        let target = url.standardizedFileURL
        let current = try open(at: target, catalog: catalog)
        guard current == expected else { throw ProjectError.concurrentModification }
        let originalManifestBytes = try Data(contentsOf: target.appendingPathComponent(manifestName))
        if let expectedManifestBytes {
            guard originalManifestBytes == expectedManifestBytes else {
                throw ProjectError.concurrentModification
            }
        }
        var sources = assetSources
        for (path, hash) in document.assetHashes where sources[path] == nil {
            guard expected.assetHashes[path] == hash else { throw ProjectError.missingAsset(path) }
            sources[path] = target.appendingPathComponent(path)
        }

        recoverOrphanedSiblings(in: target.deletingLastPathComponent())

        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".lutcalc-\(UUID().uuidString).staging", isDirectory: true)
        var replacementAttempted = false
        defer {
            if !replacementAttempted { try? FileManager.default.removeItem(at: staging) }
        }
        try saveNew(document, at: staging, catalog: catalog, assetSources: sources)

        guard try open(at: target, catalog: catalog) == expected,
              try Data(contentsOf: target.appendingPathComponent(manifestName)) == originalManifestBytes else {
            throw ProjectError.concurrentModification
        }
        let backupName = ".lutcalc-\(UUID().uuidString).backup"
        try coordinatedProjectReplacement(target: target, staging: staging,
                                          backupName: backupName,
                                          originalManifestBytes: originalManifestBytes,
                                          beforeReplacement: beforeReplacement)
        replacementAttempted = true
        guard try open(at: target, catalog: catalog) == document else {
            throw ProjectError.invalidPackage
        }
        let backup = target.deletingLastPathComponent().appendingPathComponent(backupName, isDirectory: true)
        try? FileManager.default.removeItem(at: backup)
    }

    private static func coordinatedProjectReplacement(
        target: URL, staging: URL, backupName: String,
        originalManifestBytes: Data,
        beforeReplacement: () throws -> Void
    ) throws {
        let originalFingerprint = try projectFingerprint(target,
                                                         manifestBytes: originalManifestBytes)
        var coordinationError: NSError?
        var accessorError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: target, options: [], error: &coordinationError) {
            coordinatedTarget in
            do {
                try beforeReplacement()
                let latestManifest: Data
                do {
                    latestManifest = try Data(contentsOf: coordinatedTarget
                        .appendingPathComponent(manifestName))
                } catch {
                    throw ProjectError.concurrentModification
                }
                guard latestManifest == originalManifestBytes,
                      try projectFingerprint(coordinatedTarget,
                                             manifestBytes: latestManifest) == originalFingerprint else {
                    throw ProjectError.concurrentModification
                }
                _ = try FileManager.default.replaceItemAt(
                    coordinatedTarget, withItemAt: staging, backupItemName: backupName,
                    options: [.usingNewMetadataOnly, .withoutDeletingBackupItem]
                )
            } catch {
                accessorError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let accessorError { throw accessorError }
    }

    private static func projectFingerprint(_ url: URL, manifestBytes: Data) throws -> String {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw ProjectError.concurrentModification
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value ?? 0
        let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        var hasher = SHA256()
        hasher.update(data: manifestBytes)
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "\(device):\(inode):\(digest)"
    }

    /// Removes stale staging directories left by an interrupted project
    /// replacement. Only the exact names produced by `saveExisting` are
    /// eligible; fresh entries, symlinks and unrelated files are preserved.
    /// Callers choose the age threshold so an active writer can be given a
    /// grace period before cleanup.
    public static func recoverOrphanedStaging(in directory: URL,
                                              olderThan age: TimeInterval,
                                              now: Date = Date()) throws -> [URL] {
        try recoverOrphanedDirectories(in: directory, suffix: ".staging", olderThan: age, now: now)
    }

    /// Removes stale backup directories left by an interrupted atomic project
    /// replacement. Only backups with the exact UUID naming convention emitted
    /// by `saveExisting` are eligible.
    public static func recoverOrphanedBackups(in directory: URL,
                                              olderThan age: TimeInterval,
                                              now: Date = Date()) throws -> [URL] {
        try recoverOrphanedDirectories(in: directory, suffix: ".backup", olderThan: age, now: now)
    }

    /// Removes stale temporary entries left by an interrupted local project
    /// save or file export. Only the exact UUID names emitted by native
    /// writers are eligible; both directory and regular-file temporaries are
    /// supported, while symbolic links and fresh entries are preserved.
    public static func recoverOrphanedTemporaryEntries(in directory: URL,
                                                       olderThan age: TimeInterval,
                                                       now: Date = Date()) throws -> [URL] {
        guard age.isFinite, age >= 0,
              let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true else {
            throw ProjectError.invalidPackage
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey,
                                         .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        )
        let cutoff = now.addingTimeInterval(-age)
        var removed: [URL] = []
        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix(".lutcalc-"), name.hasSuffix(".tmp"),
                  UUID(uuidString: String(name.dropFirst(9).dropLast(4))) != nil else { continue }
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey,
                                                             .isSymbolicLinkKey, .contentModificationDateKey])
            guard values.isSymbolicLink != true,
                  (values.isDirectory == true || values.isRegularFile == true),
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            try FileManager.default.removeItem(at: entry)
            removed.append(entry)
        }
        return removed.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func recoverOrphanedDirectories(in directory: URL,
                                                   suffix: String,
                                                   olderThan age: TimeInterval,
                                                   now: Date) throws -> [URL] {
        guard age.isFinite, age >= 0,
              let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true else {
            throw ProjectError.invalidPackage
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        )
        let cutoff = now.addingTimeInterval(-age)
        var removed: [URL] = []
        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix(".lutcalc-"), name.hasSuffix(suffix),
                  UUID(uuidString: String(name.dropFirst(9).dropLast(suffix.count))) != nil else { continue }
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey,
                                                             .contentModificationDateKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            try FileManager.default.removeItem(at: entry)
            removed.append(entry)
        }
        return removed.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func recoverOrphanedSiblings(in directory: URL) {
        _ = try? recoverOrphanedStaging(in: directory, olderThan: defaultOrphanRecoveryAge)
        _ = try? recoverOrphanedBackups(in: directory, olderThan: defaultOrphanRecoveryAge)
        _ = try? recoverOrphanedTemporaryEntries(in: directory, olderThan: defaultOrphanRecoveryAge)
    }

    public static func open(at url: URL, catalog: AlgorithmCatalog) throws -> ProjectManifest {
        let target = url.standardizedFileURL
        guard let packageValues = try? target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              packageValues.isDirectory == true, packageValues.isSymbolicLink != true else {
            throw ProjectError.invalidPackage
        }
        let contents: [String]
        do { contents = try FileManager.default.contentsOfDirectory(atPath: target.path) }
        catch { throw ProjectError.invalidPackage }
        guard Set(contents).isSubset(of: [manifestName, "Resources"]),
              contents.contains(manifestName) else { throw ProjectError.invalidPackage }
        let manifestURL = target.appendingPathComponent(manifestName)
        guard let manifestValues = try? manifestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              manifestValues.isRegularFile == true, manifestValues.isSymbolicLink != true else {
            throw ProjectError.invalidPackage
        }
        guard let manifestSize = manifestValues.fileSize,
              manifestSize <= ProjectCodec.maxManifestBytes else {
            throw ProjectError.manifestSizeLimit
        }
        let bytes = try Data(contentsOf: manifestURL)
        let document = try ProjectCodec.decode(bytes, catalog: catalog)
        let expectedPaths = Set(document.assetHashes.keys)
        if expectedPaths.isEmpty {
            guard !contents.contains("Resources") else { throw ProjectError.invalidPackage }
        } else {
            guard contents.contains("Resources") else { throw ProjectError.invalidPackage }
            let resourceURL = target.appendingPathComponent("Resources", isDirectory: true)
            guard let resourceValues = try? resourceURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  resourceValues.isDirectory == true, resourceValues.isSymbolicLink != true else {
                throw ProjectError.invalidPackage
            }
            let filenames = try FileManager.default.contentsOfDirectory(atPath: resourceURL.path)
            let actualPaths = Set(filenames.map { "Resources/" + $0 })
            if let missing = expectedPaths.subtracting(actualPaths).sorted().first { throw ProjectError.missingAsset(missing) }
            if let extra = actualPaths.subtracting(expectedPaths).sorted().first { throw ProjectError.unexpectedAsset(extra) }
            for path in expectedPaths.sorted() {
                let resource = target.appendingPathComponent(path)
                guard let values = try? resource.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw ProjectError.invalidPackage
                }
                let hash = try ProjectAssets.sha256(of: resource)
                guard hash == document.assetHashes[path] else { throw ProjectError.assetHashMismatch(path) }
            }
        }
        return document
    }
}
