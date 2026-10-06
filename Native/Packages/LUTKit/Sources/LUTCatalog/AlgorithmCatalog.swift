import LUTCore

public enum CatalogError: Error, Equatable, Sendable {
    case duplicateName(String)
    case missingSource(String)
    case unknownReference(String)
}

public struct TransferDescriptor: Equatable, Sendable {
    public let id: TransferID
    public let aliases: [String]
    public let source: String
    public let linearReference: LinearReference
    public let validationScope: String

    public init(id: TransferID, aliases: [String], source: String,
                linearReference: LinearReference, validationScope: String = "development") {
        self.id = id
        self.aliases = aliases
        self.source = source
        self.linearReference = linearReference
        self.validationScope = validationScope
    }
}

public struct ColorSpaceDescriptor: Equatable, Sendable {
    public let id: ColorSpaceID
    public let aliases: [String]
    public let source: String
    public let validationScope: String

    public init(id: ColorSpaceID, aliases: [String], source: String,
                validationScope: String = "development") {
        self.id = id
        self.aliases = aliases
        self.source = source
        self.validationScope = validationScope
    }
}

public struct PresetDescriptor: Equatable, Sendable {
    public let id: String
    public let settings: TransformSettings

    public init(id: String, settings: TransformSettings) {
        self.id = id
        self.settings = settings
    }
}

public struct AlgorithmCatalog: Sendable {
    public let transfers: [TransferDescriptor]
    public let colorSpaces: [ColorSpaceDescriptor]
    public let presets: [PresetDescriptor]
    private let transferNames: [String: Int]
    private let spaceNames: [String: Int]
    private let presetNames: [String: Int]

    /// Legacy registrations backed by sampled lookup data. These names are
    /// kept as an audit allowlist so a future catalog change cannot silently
    /// present an unimplemented lookup as a native formula.
    public static let blockedLookupRegistrationNames: [String] = [
        "DJI DLog-M", "DJI Mini 2", "s709", "Rec709 (800%)",
        "Nikon Standard", "Nikon Neutral", "Nikon Vivid", "Nikon Monochrome",
        "Nikon Portrait", "Nikon Landscape", "Amira709", "Alexa-X-2",
        "LC709A", "LC709", "Sony Cine+709", "Varicam V709", "REDGamma",
        "REDGamma2", "REDGamma3", "REDGamma4", "EOS Standard",
        "EOS Standard (Legal)", "Canon Normal 1", "Canon Normal 2",
        "Canon Normal 3", "Canon Normal 4", "HG3250G36 (HG1)",
        "HG4600G30 (HG2)", "HG3259G40 (HG3)", "HG4609G33 (HG4)",
        "HG8000G36 (HG5)", "HG8000G30 (HG6)", "HG8009G40 (HG7)",
        "HG8009G33 (HG8)", "Cinegamma1", "Cinegamma2", "Cinegamma3",
        "Cinegamma4", "Sony STD1", "Sony STD2 - x4.5", "Sony STD3 - x3.5",
        "Sony STD4 - SMPTE240M", "Sony STD5 - Rec709", "Sony STD6 - x5",
        "Canon WideDR"
    ]

    public init(transfers: [TransferDescriptor], colorSpaces: [ColorSpaceDescriptor],
                presets: [PresetDescriptor]) throws {
        var transferNames: [String: Int] = [:]
        for (index, item) in transfers.enumerated() {
            guard !item.source.isEmpty else { throw CatalogError.missingSource(item.id.rawValue) }
            for name in [item.id.rawValue] + item.aliases {
                guard !name.isEmpty, transferNames.updateValue(index, forKey: name) == nil else {
                    throw CatalogError.duplicateName(name)
                }
            }
        }
        var spaceNames: [String: Int] = [:]
        for (index, item) in colorSpaces.enumerated() {
            guard !item.source.isEmpty else { throw CatalogError.missingSource(item.id.rawValue) }
            for name in [item.id.rawValue] + item.aliases {
                guard !name.isEmpty, spaceNames.updateValue(index, forKey: name) == nil else {
                    throw CatalogError.duplicateName(name)
                }
            }
        }
        var presetNames: [String: Int] = [:]
        for (index, item) in presets.enumerated() {
            guard !item.id.isEmpty, presetNames.updateValue(index, forKey: item.id) == nil else {
                throw CatalogError.duplicateName(item.id)
            }
            for id in [item.settings.inputTransfer.rawValue, item.settings.outputTransfer.rawValue] {
                guard transferNames[id] != nil else { throw CatalogError.unknownReference(id) }
            }
            for id in [item.settings.inputSpace.rawValue, item.settings.outputSpace.rawValue] {
                guard spaceNames[id] != nil else { throw CatalogError.unknownReference(id) }
            }
        }
        self.transfers = transfers
        self.colorSpaces = colorSpaces
        self.presets = presets
        self.transferNames = transferNames
        self.spaceNames = spaceNames
        self.presetNames = presetNames
    }

    public func transfer(named name: String) -> TransferDescriptor? {
        transferNames[name].map { transfers[$0] }
    }

    public func colorSpace(named name: String) -> ColorSpaceDescriptor? {
        spaceNames[name].map { colorSpaces[$0] }
    }

    public func preset(named name: String) -> PresetDescriptor? {
        presetNames[name].map { presets[$0] }
    }

    public static func builtIn() throws -> AlgorithmCatalog {
        try AlgorithmCatalog(
            transfers: [
                TransferDescriptor(id: .djiDLog2, aliases: ["D-Log2"],
                    source: "DJI ACES CTL IDT.DJI.DLog2_DGamut2.a1.v1",
                    linearReference: .sceneReflectance,
                    validationScope: "D-Log2 scalar 10/12-bit and minimal plan 33³"),
                TransferDescriptor(id: .linearScene, aliases: ["Linear scene"],
                    source: "identity transfer; docs/native-swift-numeric-contracts.md",
                    linearReference: .sceneReflectance,
                    validationScope: "minimal plan 17³/33³/65³"),
                TransferDescriptor(id: .nullLUTCalcLegacy, aliases: ["Null (LUTCalc legacy)"],
                    source: NullTransfer.legacyReference,
                    linearReference: .legacyGrey02,
                    validationScope: "historical linear identity with Legal/Data wrapper; no gamut semantics"),
                TransferDescriptor(id: .srgbW3CExtended, aliases: ["sRGB"],
                    source: SRGBTransfer.referenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "scalar, minimal plan and 33³/65³ CUBE"),
                TransferDescriptor(id: .srgbLUTCalcLegacy, aliases: ["sRGB (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaGam sRGB registration and linToLegal/linFromLegal",
                    linearReference: .legacyGrey02,
                    validationScope: "scalar and four-point minimal plan only"),
                TransferDescriptor(id: .rec709LUTCalcLegacy, aliases: ["Rec.709 (LUTCalc legacy)"],
                    source: "ITU-R BT.709-6 item 1.2; js/gamma.js:LUTGammaGam Rec709 inverse threshold",
                    linearReference: .legacyGrey02,
                    validationScope: "scalar official-domain forward, old 10/12-bit decode and same-space exposure plan"),
                TransferDescriptor(id: .gpLog2, aliases: ["GoPro GP-Log2 (base 600)"],
                    source: GPLog2Transfer.referenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "normalized [0,1] base-600 scalar encode/decode only; no negative extension or camera preset"),
                TransferDescriptor(id: .smpte240M, aliases: ["SMPTE 240M"],
                    source: SMPTE240MTransfer.referenceURL + " SMPTE 240M OETF constants",
                    linearReference: .sceneReflectance,
                    validationScope: "published piecewise OETF and inverse on normalized scene values"),
                TransferDescriptor(id: .rec2020TenBit, aliases: ["Rec.2020 10-bit"],
                    source: "ITU-R BT.2020-2, Table 3 OETF practical 10-bit values",
                    linearReference: .sceneReflectance,
                    validationScope: "BT.2020 10-bit scalar branches and same-space exposure plan"),
                TransferDescriptor(id: .rec2020Continuous, aliases: ["Rec.2020 continuous"],
                    source: Rec2020ContinuousTransfer.referenceURL + " Table 3 continuous OETF constants",
                    linearReference: .sceneReflectance,
                    validationScope: "published continuous BT.2020 OETF and inverse"),
                TransferDescriptor(id: .rec2020TwelveBit, aliases: ["Rec.2020 12-bit"],
                    source: Rec2020TwelveBitTransfer.referenceSource,
                    linearReference: .legacyGrey02,
                    validationScope: "historical 12-bit parameterized gamma scalar and same-space exposure plan"),
                TransferDescriptor(id: .cineon, aliases: ["Cineon"],
                    source: CineonTransfer.referenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "published black-offset Cineon scalar and same-space plan"),
                TransferDescriptor(id: .cineonLUTCalcLegacy, aliases: ["Cineon (LUTCalc legacy)"],
                    source: CineonTransfer.legacyReference,
                    linearReference: .legacyGrey02,
                    validationScope: "historical linear toe/log scalar and same-space plan"),
                TransferDescriptor(id: .redLogFilm, aliases: ["REDLogFilm"],
                    source: REDLogFilmTransfer.referenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "registered REDLogFilm Cineon-style scalar and RED gamut route"),
                TransferDescriptor(id: .redLogFilmLUTCalcLegacy,
                    aliases: ["REDLogFilm (LUTCalc legacy)"],
                    source: REDLogFilmTransfer.referenceURL,
                    linearReference: .legacyGrey02,
                    validationScope: "registered REDLogFilm historical 0.2-domain route"),
                TransferDescriptor(id: .redLog3G10LUTCalcLegacy,
                    aliases: ["RED Log3G10 (LUTCalc legacy)"],
                    source: REDLog3G10Transfer.legacyReference,
                    linearReference: .legacyGrey02,
                    validationScope: "historical RED Log3G10 log/log threshold and LUTCalc legal-normalized data wrapper"),
                TransferDescriptor(id: .sonySLog3, aliases: ["S-Log3"],
                    source: SLog3Transfer.referenceURL + " Appendix, Sony Technical Summary V1.0",
                    linearReference: .sceneReflectance,
                    validationScope: "scalar, 10/12-bit full-code and S-Gamut3.Cine exposure plan"),
                TransferDescriptor(id: .sonySLog3LUTCalcLegacy,
                    aliases: ["S-Log3 (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog S-Log3 registration and methods",
                    linearReference: .legacyGrey02,
                    validationScope: "scalar, 10/12-bit full-code and same-space exposure plan"),
                TransferDescriptor(id: .sonySLog2, aliases: ["S-Log2"],
                    source: SonyLegacyLogTransfer.referenceURL + " Sony S-Log2 formula",
                    linearReference: .sceneReflectance,
                    validationScope: "published 0.9 reflection adaptation and S-Gamut scalar route"),
                TransferDescriptor(id: .sonySLog2LUTCalcLegacy,
                    aliases: ["S-Log2 (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog S-Log2 registration and methods",
                    linearReference: .legacyGrey02,
                    validationScope: "historical 0.2-domain scalar route"),
                TransferDescriptor(id: .sonySLog, aliases: ["S-Log"],
                    source: SonyLegacyLogTransfer.referenceURL + " Sony S-Log formula",
                    linearReference: .sceneReflectance,
                    validationScope: "published 0.9 reflection adaptation and S-Gamut scalar route"),
                TransferDescriptor(id: .sonySLogLUTCalcLegacy,
                    aliases: ["S-Log (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog S-Log registration and methods",
                    linearReference: .legacyGrey02,
                    validationScope: "historical 0.2-domain scalar route"),
                TransferDescriptor(id: .nikonNLog, aliases: ["Nikon N-Log"],
                    source: NikonNLogTransfer.referenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "published reflectance constants and branch gap; normalized data and Rec.2020 camera route"),
                TransferDescriptor(id: .nikonNLogLUTCalcLegacy, aliases: ["Nikon N-Log (LUTCalc legacy)"],
                    source: NikonNLogTransfer.legacyReference,
                    linearReference: .legacyGrey02,
                    validationScope: "historical cubic coefficient and branch cutoff; explicit 0.2/0.18 scene boundary"),
                TransferDescriptor(id: .arriLogCSUP2Scene, aliases: ["Log C SUP 2 published scene"],
                    source: ARRILogCCompact.sup2Reference,
                    linearReference: .sceneReflectance,
                    validationScope: "explicit EI 160–1600 published compact scene equations; no raw-camera gamut/default mapping or camera shoulder claim"),
                TransferDescriptor(id: .arriLogCSUP3Scene, aliases: ["Log C SUP 3 published scene"],
                    source: ARRILogCCompact.sup3ReferenceURL,
                    linearReference: .sceneReflectance,
                    validationScope: "explicit EI 160–1600 published compact scene equations; no high-EI camera shoulder claim"),
                TransferDescriptor(id: .arriLogC4, aliases: ["LogC4"],
                    source: LogC4Transfer.referenceURL + " specification May 2023; ACES CSC.Arri.LogC4_to_ACES.a2.v1",
                    linearReference: .sceneReflectance,
                    validationScope: "scalar, 10/12-bit full-code, AWG4 to AP0 matrix and ten-point plan"),
                TransferDescriptor(id:.blackmagicFilmGen5,aliases:["Blackmagic Film Gen5 published"],
                    source:BMDGen5Transfer.referenceURL,linearReference:.sceneReflectance,
                    validationScope:"published CTL branches, negative/HDR full codes and full colour grids"),
                TransferDescriptor(id:.blackmagicFilmGen5LUTCalcLegacy,aliases:["BMDFilm Gen5"],
                    source:"js/gamma.js BMDFilm Gen5 LUTGammaLog registration and methods",linearReference:.legacyGrey02,
                    validationScope:"historical coefficients and log base; distinct from published CTL"),
                TransferDescriptor(id:.canonCLog2,aliases:["Canon C-Log2"],source:CanonCLog2Transfer.referenceURL,
                    linearReference:.sceneReflectance,validationScope:"published ACES CLog2/Cinema Gamut scalar branches and CAT02 plan"),
                TransferDescriptor(id:.canonCLog2LUTCalcLegacy,aliases:["Canon C-Log2 (LUTCalc legacy)"],
                    source:"js/gamma.js:LUTGammaLog Canon C-Log2 registration and js/colourspace.js natTF=4 branches",
                    linearReference:.legacyGrey02,validationScope:"historical nine-parameter scalar branches; distinct from published CTL"),
                TransferDescriptor(id:.canonCLog3,aliases:["Canon C-Log3"],
                    source:CanonCLog3Transfer.referenceURL + " ACES Canon CLog3/Cinema Gamut CTL",
                    linearReference:.sceneReflectance,
                    validationScope:"published ACES C-Log3/Cinema Gamut scalar branches and CAT02 plan; no camera-specific shoulder or full Canon model claim"),
                TransferDescriptor(id:.canonCLogLUTCalcLegacy,aliases:["Canon C-Log (LUTCalc legacy)"],
                    source:CanonCLogTransfer.legacyReference,
                    linearReference:.legacyGrey02,
                    validationScope:"historical C-Log scalar only; Canon CP IDT and camera-specific gamut remain separate"),
                TransferDescriptor(id:.blackmagicPocketFilmLUTCalcLegacy,
                    aliases:["BMD Pocket Film (LUTCalc legacy)"],
                    source:BMDPocketFilmTransfer.legacyReference,
                    linearReference:.legacyGrey02,
                    validationScope:"historical nine-parameter scalar only; Blackmagic Pocket gamut and published identity remain separate"),
                TransferDescriptor(id: .blackmagicFilmLUTCalcLegacy,
                    aliases: ["BMD Film (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog BMD Film registration [0.261115778*0.9,-0.024248528*0.9,0.367608577,0.86786483/0.9,10,0.644065346,0.03135747,0.114002127,0.005519226/0.9]",
                    linearReference: .legacyGrey02,
                    validationScope: "historical nine-parameter scalar only; BMD Film gamut remains separate"),
                TransferDescriptor(id: .blackmagicFilm4kLUTCalcLegacy,
                    aliases: ["BMD Film4k (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog BMD Film4k registration [0.37237694*0.9,-0.034580801*0.9,0.582240088,2.617961052/0.9,10,0.461883884,0.231964429,0.10772883,0.005534931/0.9]",
                    linearReference: .legacyGrey02,
                    validationScope: "historical nine-parameter scalar only; BMD Film4k gamut remains separate"),
                TransferDescriptor(id: .blackmagicFilm46kLUTCalcLegacy,
                    aliases: ["BMD Film4.6k (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog BMD Film4.6k registration [0.195367159/0.9,-0.014273567/0.9,0.36274758,1.05345192*0.9,10,0.63659829,0.027616437,0.096214896,0.004523664*0.9]",
                    linearReference: .legacyGrey02,
                    validationScope: "historical nine-parameter scalar only; BMD Film4.6k gamut remains separate"),
                TransferDescriptor(id: .bolexLogLUTCalcLegacy, aliases: ["Bolex Log (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog Bolex Log registration [1/(5.9861078*0.9),-0.0625265/(0.9*5.9861078),0.2756705,5,10,0.4150634,0.0280665,0.1520070,0.014948/0.9]",
                    linearReference: .legacyGrey02, validationScope: "historical nine-parameter scalar only; Bolex gamut remains separate"),
                TransferDescriptor(id: .panalogLUTCalcLegacy, aliases: ["Panalog (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog Panalog registration [0.324196014,-0.020278938,0.434198361,0.956463747,10,0.665276427,0.040913561,0.088290045,0]",
                    linearReference: .legacyGrey02, validationScope: "historical nine-parameter scalar only; Rec.709 metadata is not a full Panalog camera model"),
                TransferDescriptor(id: .djiX5LogLUTCalcLegacy, aliases: ["DJI X5/X7/X9 DLog (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog DJI X5/X7/X9 DLog registration [1/(6.025*0.9),-0.0929/(6.025*0.9),0.256663,0.9892*0.9,10,0.584555,0.0108,0.14,0.0078*0.9]",
                    linearReference: .legacyGrey02, validationScope: "historical nine-parameter scalar only; DJI camera gamut remains separate"),
                TransferDescriptor(id: .goProProtuneLUTCalcLegacy, aliases: ["GoPro Protune (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog Protune registration [0,0,876/1023,53.39427221,113,64/1023,1,0,0]",
                    linearReference: .legacyGrey02, validationScope: "historical scalar wrapper only; Protune Native gamut and full GoPro camera model remain separate"),
                TransferDescriptor(id: .djiX3DLogLUTCalcLegacy, aliases: ["DJI X3 DLog (LUTCalc legacy)"],
                    source: DJIX3DLogTransfer.legacyReference,
                    linearReference: .legacyGrey02, validationScope: "historical soft-clip scalar only; DJI X3 gamut and full camera model remain separate"),
                TransferDescriptor(id: .daVinciIntermediateLUTCalcLegacy, aliases: ["DaVinci Intermediate (LUTCalc legacy)"],
                    source: DaVinciIntermediateTransfer.legacyReference,
                    linearReference: .legacyGrey02, validationScope: "historical DaVinci Intermediate scalar and legal wrapper only; DaVinci Wide Gamut workflow remains separate"),
                TransferDescriptor(id: .panasonicVLog, aliases: ["V-Log"],
                    source: VLogTransfer.referenceURL + " Rev.1.0; ACES CSC.Panasonic.VLog_VGamut_to_ACES.a2.v1",
                    linearReference: .sceneReflectance,
                    validationScope: "scalar, 10/12-bit full-code, V-Gamut to AP0 Bradford matrix and ten-point plan"),
                TransferDescriptor(id: .fujifilmFLog2, aliases: ["F-Log2"],
                    source: "Fujifilm F-Log2 Data Sheet Ver.1.1, section 2-3",
                    linearReference: .sceneReflectance,
                    validationScope: "published scalar branches and same F-Gamut minimal plan"),
                TransferDescriptor(id: .fujifilmFLog2LUTCalcLegacy, aliases: ["F-Log2 (LUTCalc legacy)"],
                    source: "js/gamma.js:LUTGammaLog Fujifilm F-Log2 registration (SHA-256 250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e), lines 215–218 and 2479–2553",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy nine-parameter scalar branches and same F-Gamut exposure plan"),
                TransferDescriptor(id: .fujifilmFLogLUTCalcLegacy,
                    aliases: ["F-Log (LUTCalc legacy)"],
                    source: FLogTransfer.legacyReference,
                    linearReference: .legacyGrey02,
                    validationScope: "historical nine-parameter scalar branches and legacy F-Gamut camera route"),
                TransferDescriptor(id: .acesCCT, aliases: ["ACEScct"],
                    source: ACESCCTTransfer.referenceURL + " ACEScct specification",
                    linearReference: .sceneReflectance,
                    validationScope: "published AP1 scalar branches and same-space exposure plan"),
                TransferDescriptor(id: .acesCC, aliases: ["ACEScc"],
                    source: ACESCCTransfer.referenceURL + " ACEScc specification",
                    linearReference: .sceneReflectance,
                    validationScope: "published AP1 scalar branches and same-space exposure plan"),
                TransferDescriptor(id: .acesProxy10, aliases: ["ACESproxy10"],
                    source: ACESProxyTransfer.referenceURL + " ACESproxy 10-bit encoding",
                    linearReference: .sceneReflectance,
                    validationScope: "published 10-bit SDI code mapping and same-space exposure plan"),
                TransferDescriptor(id: .acesProxy12, aliases: ["ACESproxy12"],
                    source: ACESProxyTransfer.referenceURL + " ACESproxy 12-bit encoding",
                    linearReference: .sceneReflectance,
                    validationScope: "published 12-bit SDI code mapping and same-space exposure plan"),
                TransferDescriptor(id: .insta360ILog, aliases: ["Insta360 I-Log"],
                    source: "Insta360 I-Log White Paper, June 2026, conversion specification",
                    linearReference: .sceneReflectance,
                    validationScope: "published scalar branches and BT.2020 same-space exposure plan"),
                TransferDescriptor(id: .xiaomiMiLog, aliases: ["Xiaomi Mi-Log"],
                    source: "Xiaomi Log Profile White Paper, December 2024, sections 3.1–3.2",
                    linearReference: .sceneReflectance,
                    validationScope: "published 10-bit three-segment curve and BT.2020 same-space exposure plan"),
                TransferDescriptor(id: .leicaLLog, aliases: ["Leica L-Log"],
                    source: "Leica L-Log Reference Manual V1.9, sections 4.1–4.2",
                    linearReference: .sceneReflectance,
                    validationScope: "BT.2020 camera subset scalar branches and same-space exposure plan; SL Typ 601 excluded"),
                TransferDescriptor(id: .kineLog3, aliases: ["KineLOG3"],
                    source: "Kinefinity KineLOG3 Technical Specifications, sections 2–3",
                    linearReference: .sceneReflectance,
                    validationScope: "published scalar branches and Kinefinity Wide Gamut same-space exposure plan; listed camera scope only"),
                TransferDescriptor(id: .appleLogOriginal, aliases: ["Apple Log"],
                    source: AppleLogTransfer.referenceURL + " ACES CSC.Apple.AppleLog_to_ACES.a2.v1",
                    linearReference: .sceneReflectance,
                    validationScope: "ACES original Apple Log scalar, 10/12-bit, Rec.2020 to AP0 Bradford plan"),
                TransferDescriptor(id: .appleLog2, aliases: ["Apple Log 2"],
                    source: AppleLogTransfer.log2ReferenceURL + " ACES CSC.Apple.AppleLog2_to_ACES.a2.v1",
                    linearReference: .sceneReflectance,
                    validationScope: "ACES Apple Log 2 scalar, 10/12-bit, Apple Wide Gamut to AP0 Bradford plan"),
                TransferDescriptor(id: .rec2100HLG, aliases: ["Rec2100 HLG"],
                    source: HLGTransfer.referenceURL + " Table 5",
                    linearReference: .sceneReflectance,
                    validationScope: "BT.2100-3 OETF/inverse OETF scalar; OOTF/display parameters separate"),
                TransferDescriptor(id: .rec2100PQ, aliases: ["Rec2100 PQ"],
                    source: PQTransfer.referenceURL + " SMPTE ST 2084 / BT.2100 PQ constants",
                    linearReference: .sceneReflectance,
                    validationScope: "normalized absolute luminance scalar; display peak and OOTF separate"),
                TransferDescriptor(id: .bt1886, aliases: ["BT.1886"],
                    source: BT1886Transfer.referenceURL + " Annex 1",
                    linearReference: .absoluteNits,
                    validationScope: "parameterized reference-display EOTF/inverse scalar; no HDR/OOTF"),
                TransferDescriptor(id: .cieLStar, aliases: ["CIE L*"],
                    source: CIELStarTransfer.referenceURL + "; js/gamma.js:LUTGammaGam CIE L* registration",
                    linearReference: .legacyGrey02,
                    validationScope: "normalized CIE L* scalar with explicit LUTCalc data wrapper; CIELAB color space separate"),
                TransferDescriptor(id: .proPhoto, aliases: ["ProPhoto / ROMM"],
                    source: ProPhotoTransfer.referenceURL,
                    linearReference: .legacyGrey02,
                    validationScope: "analytic 16x toe and gamma 1.8 scalar with LUTCalc data wrapper; same-space minimal plan"),
                TransferDescriptor(id: .bbc04, aliases: ["BBC 0.4"],
                    source: "js/gamma.js:LUTGammaBBCGam BBC 0.4 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "analytic six-parameter scalar and same-space minimal plan"),
                TransferDescriptor(id: .bbc05, aliases: ["BBC 0.5"],
                    source: "js/gamma.js:LUTGammaBBCGam BBC 0.5 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "analytic six-parameter scalar and same-space minimal plan"),
                TransferDescriptor(id: .bbc06, aliases: ["BBC 0.6"],
                    source: "js/gamma.js:LUTGammaBBCGam BBC 0.6 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "analytic six-parameter scalar and same-space minimal plan"),
                TransferDescriptor(id: .bbcWHP283400, aliases: ["BBC WHP283 (400%)"],
                    source: BBCWHP283Transfer.referenceSource + "; registration m=0.139401137752",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy WHP283 analytic scalar and same-space 33³/65³ readback; fixed system gamma s=1"),
                TransferDescriptor(id: .bbcWHP283800, aliases: ["BBC WHP283 (800%)"],
                    source: BBCWHP283Transfer.referenceSource + "; registration m=0.097401889128",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy WHP283 analytic scalar and same-space 33³/65³ readback; fixed system gamma s=1"),
                TransferDescriptor(id: .ituProposal400, aliases: ["ITU Proposal (400%)"],
                    source: ITUProposalTransfer.referenceSource + "; registration m=0.12314858",
                    linearReference: .legacyGrey02,
                    validationScope: "historical analytic Rec.2020 toe and tangent logarithmic shoulder; not a standards-conformance claim"),
                TransferDescriptor(id: .ituProposal800, aliases: ["ITU Proposal (800%)"],
                    source: ITUProposalTransfer.referenceSource + "; registration m=0.083822216783",
                    linearReference: .legacyGrey02,
                    validationScope: "historical analytic Rec.2020 toe and tangent logarithmic shoulder; not a standards-conformance claim"),
                TransferDescriptor(id: .gamma15, aliases: ["γ1.5"],
                    source: "js/gamma.js:LUTGammaGam γ1.5 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma16, aliases: ["γ1.6"],
                    source: "js/gamma.js:LUTGammaGam γ1.6 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma17, aliases: ["γ1.7"],
                    source: "js/gamma.js:LUTGammaGam γ1.7 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma18, aliases: ["γ1.8"],
                    source: "js/gamma.js:LUTGammaGam γ1.8 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma19, aliases: ["γ1.9"],
                    source: "js/gamma.js:LUTGammaGam γ1.9 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma20, aliases: ["γ2.0"],
                    source: "js/gamma.js:LUTGammaGam γ2.0 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma21, aliases: ["γ2.1"],
                    source: "js/gamma.js:LUTGammaGam γ2.1 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma22, aliases: ["γ2.2"],
                    source: "js/gamma.js:LUTGammaGam γ2.2 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma23, aliases: ["γ2.3"],
                    source: "js/gamma.js:LUTGammaGam γ2.3 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma24, aliases: ["γ2.4"],
                    source: "js/gamma.js:LUTGammaGam γ2.4 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma25, aliases: ["γ2.5"],
                    source: "js/gamma.js:LUTGammaGam γ2.5 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .gamma26, aliases: ["γ2.6"],
                    source: "js/gamma.js:LUTGammaGam γ2.6 registration",
                    linearReference: .legacyGrey02,
                    validationScope: "legacy low-end linear branch and power branch"),
                TransferDescriptor(id: .parameterizedGamma, aliases: ["Parameterized Gamma"],
                    source: ParameterizedGammaTransfer.referenceSource + "; ParameterizedGammaSettings",
                    linearReference: .legacyGrey02,
                    validationScope: "persisted analytic parameters; runtime values validated by TransformPlan"),
            ],
            colorSpaces: [
                ColorSpaceDescriptor(id: .djiDGamut2, aliases: ["D-Gamut2"],
                    source: "DJI ACES CTL IDT.DJI.DLog2_DGamut2.a1.v1",
                    validationScope: "toXYZ and CAT02 to AP0 independent fixture"),
                ColorSpaceDescriptor(id: .acesAP0, aliases: ["ACES AP0"],
                    source: "ACES AP0 primaries; tests/fixtures/dlog2-reference.json:toAP0",
                    validationScope: "DJI to AP0 minimal plan"),
                ColorSpaceDescriptor(id: .srgb, aliases: ["sRGB D65"],
                    source: SRGBTransfer.referenceURL,
                    validationScope: "W3C rational XYZ inverse and 33³/65³ minimal plan"),
                ColorSpaceDescriptor(id: .sonySGamut3Cine, aliases: ["S-Gamut3.Cine"],
                    source: SLog3Transfer.referenceURL + " final page chromaticity table",
                    validationScope: "Sony V1.0 primaries and same-space exposure plan"),
                ColorSpaceDescriptor(id: .sonySGamut3, aliases: ["S-Gamut3"],
                    source: "ACES CSC.Sony.SLog3_SGamut3_to_ACES.a2.v1, Sony supplied primaries",
                    validationScope: "Sony/ACES CTL CAT02 to AP0 matrix, ten RGB points and 33³/65³ CUBE"),
                ColorSpaceDescriptor(id: .sonySGamut, aliases: ["S-Gamut"],
                    source: "Sony S-Gamut primaries (0.730,0.280 / 0.140,0.855 / 0.100,-0.050), D65",
                    validationScope: "Sony S-Gamut matrix and S-Log/S-Log2 camera route"),
                ColorSpaceDescriptor(id: .redWideGamutRGB, aliases: ["REDWideGamutRGB"],
                    source: "js/colourspace.js: REDWideGamutRGB primaries, D65",
                    validationScope: "published chromaticity-derived RGB to XYZ matrix"),
                ColorSpaceDescriptor(id: .arriWideGamut4, aliases: ["ARRI Wide Gamut 4"],
                    source: LogC4Transfer.referenceURL + " section 4.2; ACES CSC.Arri.LogC4_to_ACES.a2.v1",
                    validationScope: "ARRI published AP0 CAT02 matrix and ten-point plan"),
                ColorSpaceDescriptor(id: .arriWideGamut3, aliases: ["ARRI Wide Gamut 3", "ALEXA Wide Gamut"],
                    source: ARRILogCCompact.sup3ReferenceURL + " published chromaticities, D65; ARRI 2012 VFX page 10",
                    validationScope: "rational XYZ/CAT02/Bradford matrices; explicit SUP 3 scene EI; full colour codes and 33³/65³"),
                ColorSpaceDescriptor(id:.blackmagicWideGamutGen5,aliases:["Blackmagic Wide Gamut"],
                    source:BMDGen5Transfer.referenceURL,validationScope:"published primaries and precise white, rational CAT02/Bradford matrices"),
                ColorSpaceDescriptor(id:.canonCinemaGamut,aliases:["Canon Cinema Gamut"],
                    source:CanonCLog2Transfer.referenceURL,validationScope:"published chromaticities and CAT02 matrix to ACES AP0"),
                ColorSpaceDescriptor(id: .panasonicVGamut, aliases: ["V-Gamut"],
                    source: VLogTransfer.referenceURL + " section 4.1; ACES CSC.Panasonic.VLog_VGamut_to_ACES.a2.v1",
                    validationScope: "Panasonic primaries and ACES Bradford to AP0 matrix, ten-point plan"),
                ColorSpaceDescriptor(id: .fujifilmFGamut, aliases: ["F-Gamut"],
                    source: "Fujifilm F-Log2 Data Sheet Ver.1.1, section 3",
                    validationScope: "published primaries; same-space minimal plan"),
                ColorSpaceDescriptor(id: .fujifilmFGamutC, aliases: ["F-Gamut C", "F-Log2 C"],
                    source: "https://dl.fujifilm-x.com/support/lut/F-Log2C_DataSheet_E_Ver.1.0.pdf, section 3",
                    validationScope: "published F-Gamut C primaries; F-Log2 C same-transfer cross-gamut plan"),
                ColorSpaceDescriptor(id: .acesAP1, aliases: ["ACEScg AP1", "ACES AP1"],
                    source: ACESCCTTransfer.referenceURL + " color space chromaticities",
                    validationScope: "published AP1 primaries and ACEScct same-space plan"),
                ColorSpaceDescriptor(id: .rec2020, aliases: ["Rec.2020"],
                    source: AppleLogTransfer.referenceURL + " Rec.2020 primaries in ACES CTL",
                    validationScope: "Apple original Log to AP0 Bradford matrix and ten-point plan"),
                ColorSpaceDescriptor(id: .displayP3, aliases: ["Display P3", "P3-D65"],
                    source: "https://developer.apple.com/documentation/coregraphics/cgcolorspace/displayp3",
                    validationScope: "published Display P3 D65 primaries and independently derived Double RGB-to-XYZ matrix"),
                ColorSpaceDescriptor(id: .appleWideGamut, aliases: ["Apple Wide Gamut"],
                    source: AppleLogTransfer.log2ReferenceURL + " Apple Wide Gamut primaries in ACES CTL",
                    validationScope: "Apple Log 2 to AP0 Bradford matrix and ten-point plan"),
                ColorSpaceDescriptor(id: .kinefinityWideGamut, aliases: ["Kinefinity Wide Gamut"],
                    source: KineLog3Transfer.referenceURL + " appendix",
                    validationScope: "published Kinefinity Wide Gamut primaries; same-space KineLOG3 plan only"),
                ColorSpaceDescriptor(id: .proPhoto, aliases: ["ProPhoto RGB", "ROMM RGB"],
                    source: "ITU-R BT.2380-0 §2.7 RIMM-ROMM chromaticities; js/colourspace.js ProPhoto RGB registration",
                    validationScope: "D50 primaries and analytic conversion matrix"),
                ColorSpaceDescriptor(id: .bt601SMPTEC, aliases: ["BT.601 525 (SMPTE-C)", "SMPTE-C"],
                    source: "ITU-R BT.2380-0 §2.2, SMPTE-C chromaticities",
                    validationScope: "published SMPTE-C D65 primaries and analytic Double RGB-to-XYZ matrix"),
                ColorSpaceDescriptor(id: .bt601EBU, aliases: ["BT.601 625 (EBU)", "EBU 3213"],
                    source: "ITU-R BT.2380-0 §2.2, EBU 3213 chromaticities",
                    validationScope: "published EBU 3213 D65 primaries and analytic Double RGB-to-XYZ matrix"),
                ColorSpaceDescriptor(id: .smpte240M, aliases: ["SMPTE 240M"],
                    source: "ITU-R BT.2380-0 section 2.3, SMPTE 240M chromaticities",
                    validationScope: "published SMPTE 240M D65 primaries and analytic Double RGB-to-XYZ matrix"),
            ],
            presets: [
                PresetDescriptor(id:"blackmagic.film-gen5-to-linear-ap0-published.v1",settings:TransformSettings(
                    inputTransfer:.blackmagicFilmGen5,outputTransfer:.linearScene,inputSpace:.blackmagicWideGamutGen5,outputSpace:.acesAP0,
                    inputRange:.data,outputRange:.data,exposureStops:0)),
                PresetDescriptor(id:"blackmagic.film-gen5-to-linear-ap0-legacy.v1",settings:TransformSettings(
                    inputTransfer:.blackmagicFilmGen5LUTCalcLegacy,outputTransfer:.linearScene,inputSpace:.blackmagicWideGamutGen5,outputSpace:.acesAP0,
                    inputRange:.data,outputRange:.data,exposureStops:0)),
                PresetDescriptor(id:"canon.c-log2-to-linear-ap0-published.v1",settings:TransformSettings(
                    inputTransfer:.canonCLog2,outputTransfer:.linearScene,inputSpace:.canonCinemaGamut,outputSpace:.acesAP0,
                    inputRange:.data,outputRange:.data,exposureStops:0)),
                PresetDescriptor(id:"canon.c-log2-to-linear-ap0-legacy.v1",settings:TransformSettings(
                    inputTransfer:.canonCLog2LUTCalcLegacy,outputTransfer:.linearScene,inputSpace:.canonCinemaGamut,outputSpace:.acesAP0,
                    inputRange:.data,outputRange:.data,exposureStops:0)),
                PresetDescriptor(id:"canon.c-log3-to-linear-ap0-published.v1",settings:TransformSettings(
                    inputTransfer:.canonCLog3,outputTransfer:.linearScene,inputSpace:.canonCinemaGamut,outputSpace:.acesAP0,
                    inputRange:.data,outputRange:.data,exposureStops:0)),
                PresetDescriptor(id: "dji.dlog2-to-dlog2-identity.v1", settings: TransformSettings(
                    inputTransfer: .djiDLog2, outputTransfer: .djiDLog2,
                    inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
                    inputRange: .data, outputRange: .data, exposureStops: 0
                )),
                PresetDescriptor(id: "dji.dlog2-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                    inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "dji.dlog2-to-srgb-w3c.v1", settings: TransformSettings(
                    inputTransfer: .djiDLog2, outputTransfer: .srgbW3CExtended,
                    inputSpace: .djiDGamut2, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "null.legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .nullLUTCalcLegacy, outputTransfer: .nullLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "rec709.legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .rec709LUTCalcLegacy, outputTransfer: .rec709LUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "rec2020.10bit-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .rec2020TenBit, outputTransfer: .rec2020TenBit,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "rec2020.continuous-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .rec2020Continuous, outputTransfer: .rec2020Continuous,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "rec2020.12bit-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .rec2020TwelveBit, outputTransfer: .rec2020TwelveBit,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "nikon.nlog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .nikonNLogLUTCalcLegacy, outputTransfer: .nikonNLogLUTCalcLegacy,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "nikon.nlog-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .nikonNLog, outputTransfer: .nikonNLog,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "cineon.exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .cineon, outputTransfer: .linearScene,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "cineon.legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .cineonLUTCalcLegacy, outputTransfer: .cineonLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "red.logfilm-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .redLogFilm, outputTransfer: .linearScene,
                    inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "red.logfilm-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .redLogFilmLUTCalcLegacy, outputTransfer: .redLogFilmLUTCalcLegacy,
                    inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "red.log3g10-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .redLog3G10LUTCalcLegacy, outputTransfer: .redLog3G10LUTCalcLegacy,
                    inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog3-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog3, outputTransfer: .sonySLog3,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog3-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog3LUTCalcLegacy, outputTransfer: .sonySLog3LUTCalcLegacy,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog3-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog3, outputTransfer: .linearScene,
                    inputSpace: .sonySGamut3Cine, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog3-sgamut3-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog3, outputTransfer: .linearScene,
                    inputSpace: .sonySGamut3, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog2-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog2, outputTransfer: .sonySLog2,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog2-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog2LUTCalcLegacy, outputTransfer: .sonySLog2LUTCalcLegacy,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLog, outputTransfer: .sonySLog,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "sony.slog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .sonySLogLUTCalcLegacy, outputTransfer: .sonySLogLUTCalcLegacy,
                    inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "canon.clog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .canonCLogLUTCalcLegacy, outputTransfer: .canonCLogLUTCalcLegacy,
                    inputSpace: .canonCinemaGamut, outputSpace: .canonCinemaGamut,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "blackmagic.pocket-film-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .blackmagicPocketFilmLUTCalcLegacy, outputTransfer: .blackmagicPocketFilmLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "blackmagic.film-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .blackmagicFilmLUTCalcLegacy, outputTransfer: .blackmagicFilmLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "blackmagic.film4k-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .blackmagicFilm4kLUTCalcLegacy, outputTransfer: .blackmagicFilm4kLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "blackmagic.film46k-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .blackmagicFilm46kLUTCalcLegacy, outputTransfer: .blackmagicFilm46kLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "bolex.log-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .bolexLogLUTCalcLegacy, outputTransfer: .bolexLogLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "panalog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .panalogLUTCalcLegacy, outputTransfer: .panalogLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "dji.x5-log-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .djiX5LogLUTCalcLegacy, outputTransfer: .djiX5LogLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "gopro.protune-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .goProProtuneLUTCalcLegacy, outputTransfer: .goProProtuneLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "dji.x3-dlog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .djiX3DLogLUTCalcLegacy, outputTransfer: .djiX3DLogLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "davinci.intermediate-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .daVinciIntermediateLUTCalcLegacy, outputTransfer: .daVinciIntermediateLUTCalcLegacy,
                    inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "arri.logc4-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .arriLogC4, outputTransfer: .linearScene,
                    inputSpace: .arriWideGamut4, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "panasonic.vlog-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .panasonicVLog, outputTransfer: .linearScene,
                    inputSpace: .panasonicVGamut, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1,
                    adaptation: .bradford
                )),
                PresetDescriptor(id: "fujifilm.flog2-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .fujifilmFLog2, outputTransfer: .fujifilmFLog2,
                    inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "fujifilm.flog2c-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .fujifilmFLog2, outputTransfer: .fujifilmFLog2,
                    inputSpace: .fujifilmFGamutC, outputSpace: .fujifilmFGamutC,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "fujifilm.flog2-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .fujifilmFLog2LUTCalcLegacy, outputTransfer: .fujifilmFLog2LUTCalcLegacy,
                    inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "fujifilm.flog-legacy-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .fujifilmFLogLUTCalcLegacy, outputTransfer: .fujifilmFLogLUTCalcLegacy,
                    inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "aces.acescct-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .acesCCT, outputTransfer: .acesCCT,
                    inputSpace: .acesAP1, outputSpace: .acesAP1,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "aces.acescc-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .acesCC, outputTransfer: .acesCC,
                    inputSpace: .acesAP1, outputSpace: .acesAP1,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "aces.acesproxy10-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .acesProxy10, outputTransfer: .acesProxy10,
                    inputSpace: .acesAP1, outputSpace: .acesAP1,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "aces.acesproxy12-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .acesProxy12, outputTransfer: .acesProxy12,
                    inputSpace: .acesAP1, outputSpace: .acesAP1,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "insta360.ilog-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .insta360ILog, outputTransfer: .linearScene,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "xiaomi.milog-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .xiaomiMiLog, outputTransfer: .linearScene,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "leica.llog-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .leicaLLog, outputTransfer: .linearScene,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "kinefinity.kinelog3-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .kineLog3, outputTransfer: .linearScene,
                    inputSpace: .kinefinityWideGamut, outputSpace: .kinefinityWideGamut,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "apple.log-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .appleLogOriginal, outputTransfer: .linearScene,
                    inputSpace: .rec2020, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1,
                    adaptation: .bradford
                )),
                PresetDescriptor(id: "apple.log2-to-linear-ap0.v1", settings: TransformSettings(
                    inputTransfer: .appleLog2, outputTransfer: .linearScene,
                    inputSpace: .appleWideGamut, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1,
                    adaptation: .bradford
                )),
                PresetDescriptor(id: "rec2100.hlg-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .rec2100HLG, outputTransfer: .rec2100HLG,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "rec2100.pq-reference.v1", settings: TransformSettings(
                    inputTransfer: .rec2100PQ, outputTransfer: .rec2100PQ,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 0
                )),
                PresetDescriptor(id: "bt1886.reference-display.v1", settings: TransformSettings(
                    inputTransfer: .bt1886, outputTransfer: .bt1886,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 0
                )),
                PresetDescriptor(id: "cie.l-star-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .cieLStar, outputTransfer: .cieLStar,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "romm.prophoto-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .proPhoto, outputTransfer: .proPhoto,
                    inputSpace: .proPhoto, outputSpace: .proPhoto,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "bbc.gamma-batch-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .bbc04, outputTransfer: .bbc04,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "bbc.whp283-400-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .bbcWHP283400, outputTransfer: .bbcWHP283400,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "bbc.whp283-800-exposure-one.v1", settings: TransformSettings(
                    inputTransfer: .bbcWHP283800, outputTransfer: .bbcWHP283800,
                    inputSpace: .srgb, outputSpace: .srgb,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "itu.proposal-400-exposure-one-legacy.v1", settings: TransformSettings(
                    inputTransfer: .ituProposal400, outputTransfer: .ituProposal400,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
                PresetDescriptor(id: "itu.proposal-800-exposure-one-legacy.v1", settings: TransformSettings(
                    inputTransfer: .ituProposal800, outputTransfer: .ituProposal800,
                    inputSpace: .rec2020, outputSpace: .rec2020,
                    inputRange: .data, outputRange: .data, exposureStops: 1
                )),
            ] + (try ARRILogCCompact.supportedExposureIndices.map { ei in
                PresetDescriptor(id: "arri.logc-sup3-ei\(ei)-awg3-to-linear-ap0-published.v1", settings: TransformSettings(
                    inputTransfer: .arriLogCSUP3Scene, outputTransfer: .linearScene,
                    inputSpace: .arriWideGamut3, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 0,
                    inputLogC: try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: ei)
                ))
            })
        )
    }
}
