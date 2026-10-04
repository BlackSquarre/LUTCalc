import Foundation

public enum TransferID: String, Codable, Sendable {
    case djiDLog2 = "dji.dlog2.v1"
    case linearScene = "linear.scene.v1"
    case nullLUTCalcLegacy = "null.lutcalc-legacy.v1"
    case srgbW3CExtended = "srgb.w3c-extended.v1"
    case srgbLUTCalcLegacy = "srgb.lutcalc-legacy.v1"
    case rec709LUTCalcLegacy = "rec709.lutcalc-legacy.v1"
    case rec2020TenBit = "rec2020.bt2020-10bit.v1"
    case rec2020TwelveBit = "rec2020.bt2020-12bit-lutcalc-legacy.v1"
    case cineon = "cineon.v1"
    case cineonLUTCalcLegacy = "cineon.lutcalc-legacy.v1"
    case redLogFilm = "red.logfilm.v1"
    case redLogFilmLUTCalcLegacy = "red.logfilm.lutcalc-legacy.v1"
    case redLog3G10LUTCalcLegacy = "red.log3g10.lutcalc-legacy.v1"
    case sonySLog3 = "sony.slog3.v1"
    case sonySLog3LUTCalcLegacy = "slog3.lutcalc-legacy.v1"
    case sonySLog2 = "sony.slog2.v1"
    case sonySLog2LUTCalcLegacy = "sony.slog2.lutcalc-legacy.v1"
    case sonySLog = "sony.slog.v1"
    case sonySLogLUTCalcLegacy = "sony.slog.lutcalc-legacy.v1"
    case nikonNLog = "nikon.nlog.v1"
    case nikonNLogLUTCalcLegacy = "nikon.nlog.lutcalc-legacy.v1"
    case arriLogCSUP2Scene = "arri.logc-sup2-scene-published.v1"
    case arriLogCSUP3Scene = "arri.logc-sup3-scene-published.v1"
    case arriLogC4 = "arri.logc4.v1"
    case blackmagicFilmGen5 = "blackmagic.film-gen5-published.v1"
    case blackmagicFilmGen5LUTCalcLegacy = "blackmagic.film-gen5-lutcalc-legacy.v1"
    case blackmagicFilmLUTCalcLegacy = "blackmagic.film-lutcalc-legacy.v1"
    case blackmagicFilm4kLUTCalcLegacy = "blackmagic.film4k-lutcalc-legacy.v1"
    case blackmagicFilm46kLUTCalcLegacy = "blackmagic.film4.6k-lutcalc-legacy.v1"
    case bolexLogLUTCalcLegacy = "bolex.log.lutcalc-legacy.v1"
    case panalogLUTCalcLegacy = "panalog.lutcalc-legacy.v1"
    case djiX5LogLUTCalcLegacy = "dji.x5-log.lutcalc-legacy.v1"
    case goProProtuneLUTCalcLegacy = "gopro.protune.lutcalc-legacy.v1"
    case djiX3DLogLUTCalcLegacy = "dji.x3-dlog.lutcalc-legacy.v1"
    case daVinciIntermediateLUTCalcLegacy = "davinci.intermediate.lutcalc-legacy.v1"
    case canonCLog2 = "canon.c-log2-published.v1"
    case canonCLog2LUTCalcLegacy = "canon.c-log2-lutcalc-legacy.v1"
    case canonCLog3 = "canon.c-log3-published.v1"
    case canonCLogLUTCalcLegacy = "canon.c-log.lutcalc-legacy.v1"
    case blackmagicPocketFilmLUTCalcLegacy = "blackmagic.pocket-film.lutcalc-legacy.v1"
    case panasonicVLog = "panasonic.vlog.v1"
    case fujifilmFLog2 = "fujifilm.flog2.v1"
    case fujifilmFLog2LUTCalcLegacy = "fujifilm.flog2.lutcalc-legacy.v1"
    case fujifilmFLogLUTCalcLegacy = "fujifilm.flog.lutcalc-legacy.v1"
    case acesCCT = "aces.cct.v1"
    case acesCC = "aces.cc.v1"
    case acesProxy10 = "aces.proxy10.v1"
    case acesProxy12 = "aces.proxy12.v1"
    case insta360ILog = "insta360.ilog.v1"
    case xiaomiMiLog = "xiaomi.milog.v1"
    case leicaLLog = "leica.llog.v1"
    case kineLog3 = "kinefinity.kinelog3.v1"
    case appleLogOriginal = "apple.log-original.v1"
    case appleLog2 = "apple.log2.v1"
    case rec2100HLG = "rec2100.hlg.v1"
    case rec2100PQ = "rec2100.pq.v1"
    case bt1886 = "bt1886.eotf.v1"
    case proPhoto = "romm.prophoto.v1"
    case bbc04 = "bbc.gamma-0-4.v1"
    case bbc05 = "bbc.gamma-0-5.v1"
    case bbc06 = "bbc.gamma-0-6.v1"
    case bbcWHP283400 = "bbc.whp283-400.v1"
    case bbcWHP283800 = "bbc.whp283-800.v1"
    case ituProposal400 = "itu.proposal-400-legacy.v1"
    case ituProposal800 = "itu.proposal-800-legacy.v1"
    case parameterizedGamma = "gamma.parameterized.v1"
    case gamma15 = "gamma.1-5.v1"
    case gamma16 = "gamma.1-6.v1"
    case gamma17 = "gamma.1-7.v1"
    case gamma18 = "gamma.1-8.v1"
    case gamma19 = "gamma.1-9.v1"
    case gamma20 = "gamma.2-0.v1"
    case gamma21 = "gamma.2-1.v1"
    case gamma22 = "gamma.2-2.v1"
    case gamma23 = "gamma.2-3.v1"
    case gamma24 = "gamma.2-4.v1"
    case gamma25 = "gamma.2-5.v1"
    case gamma26 = "gamma.2-6.v1"
    case cieLStar = "cie.l-star.v1"
}

public enum ColorSpaceID: String, Codable, Sendable {
    case djiDGamut2 = "dji.dgamut2.v1"
    case acesAP0 = "aces.ap0.v1"
    case srgb = "srgb.d65.v1"
    case sonySGamut3Cine = "sony.sgamut3cine.v1"
    case sonySGamut3 = "sony.sgamut3.v1"
    case sonySGamut = "sony.sgamut.v1"
    case redWideGamutRGB = "red.wide-gamut-rgb.v1"
    case arriWideGamut4 = "arri.awg4.v1"
    case arriWideGamut3 = "arri.awg3.v1"
    case blackmagicWideGamutGen5 = "blackmagic.wide-gamut-gen5.v1"
    case canonCinemaGamut = "canon.cinema-gamut.v1"
    case panasonicVGamut = "panasonic.vgamut.v1"
    case fujifilmFGamut = "fujifilm.fgamut.v1"
    case fujifilmFGamutC = "fujifilm.fgamut-c.v1"
    case acesAP1 = "aces.ap1.v1"
    case rec2020 = "rec2020.d65.v1"
    case displayP3 = "display.p3-d65.v1"
    case appleWideGamut = "apple.wide-gamut.v1"
    case kinefinityWideGamut = "kinefinity.wide-gamut.v1"
    case proPhoto = "romm.prophoto-d50.v1"

    var primaries: ColorPrimaries {
        switch self {
        case .djiDGamut2: .djiDGamut2
        case .acesAP0: .acesAP0
        case .srgb: .srgb
        case .sonySGamut3Cine: .sonySGamut3Cine
        case .sonySGamut3: .sonySGamut3
        case .sonySGamut: .sonySGamut
        case .redWideGamutRGB: .redWideGamutRGB
        case .arriWideGamut4: .arriWideGamut4
        case .arriWideGamut3: .arriWideGamut3
        case .blackmagicWideGamutGen5: .blackmagicWideGamutGen5
        case .canonCinemaGamut: .canonCinemaGamut
        case .panasonicVGamut: .panasonicVGamut
        case .fujifilmFGamut: .fujifilmFGamut
        case .fujifilmFGamutC: .fujifilmFGamutC
        case .acesAP1: .acesAP1
        case .rec2020: .rec2020
        case .displayP3: .displayP3
        case .appleWideGamut: .appleWideGamut
        case .kinefinityWideGamut: .kinefinityWideGamut
        case .proPhoto: .proPhoto
        }
    }
}

public enum SignalNormalization: String, Codable, Sendable {
    case data
    case video
}

public enum SignalUnit: String, Sendable {
    case encodedData
    case encodedVideo
    case sceneReflectance
    case encodedLegal
    case diagnosticPaletteMixed
    case legacyLinearIRE
    case displayLuminance
}

public struct TransformSettings: Equatable, Codable, Sendable {
    public let cameraExposure: CameraExposureSettings?
    public let inputTransfer: TransferID
    public let outputTransfer: TransferID
    public let inputSpace: ColorSpaceID
    public let outputSpace: ColorSpaceID
    public let inputRange: SignalNormalization
    public let outputRange: SignalNormalization
    public let exposureStops: Double
    public let rangeBitDepth: Int
    public let adaptation: ChromaticAdaptation
    public let inputGamma: ParameterizedGammaSettings?
    public let outputGamma: ParameterizedGammaSettings?
    public let inputLogC: ARRILogCSceneSettings?
    public let outputLogC: ARRILogCSceneSettings?
    public let ascCDL: ASCCDLSettings?
    public let sdrSaturation: SDRSaturationSettings?
    public let multitone: MultitoneSettings?
    public let blackGamma: BlackGammaSettings?
    public let blackHighlight: BlackHighlightSettings?
    public let knee: KneeSettings?
    public let highlightGamut: HighlightGamutSettings?
    public let gamutLimiter: GamutLimiterSettings?
    public let outputCodeUnits:OutputCodeUnitPolicy
    public let displayConversion:DisplayConversionSettings?
    public let falseColour:FalseColourSettings?
    public let finalOutput:FinalOutputSettings?
    public let hlgOOTF: HLGOOTFSettings?
    public var requiresOutputCodeUnitIdentity:Bool {outputTransfer.usesRoundedLegacyDataWrapper || outputCodeUnits != .completeV2}

    public init(
        inputTransfer: TransferID, outputTransfer: TransferID,
        inputSpace: ColorSpaceID, outputSpace: ColorSpaceID,
        inputRange: SignalNormalization, outputRange: SignalNormalization,
        exposureStops: Double, rangeBitDepth: Int = 10,
        adaptation: ChromaticAdaptation = .cieCAT02,
        inputGamma: ParameterizedGammaSettings? = nil,
        outputGamma: ParameterizedGammaSettings? = nil,
        ascCDL: ASCCDLSettings? = nil,
        sdrSaturation: SDRSaturationSettings? = nil,
        multitone: MultitoneSettings? = nil,
        blackGamma: BlackGammaSettings? = nil,
        blackHighlight: BlackHighlightSettings? = nil,
        knee: KneeSettings? = nil,
        highlightGamut: HighlightGamutSettings? = nil,
        gamutLimiter: GamutLimiterSettings? = nil,
        outputCodeUnits:OutputCodeUnitPolicy = .completeV2,
        displayConversion:DisplayConversionSettings? = nil,
        falseColour:FalseColourSettings? = nil,
        finalOutput:FinalOutputSettings? = nil,
        inputLogC: ARRILogCSceneSettings? = nil,
        outputLogC: ARRILogCSceneSettings? = nil,
        cameraExposure: CameraExposureSettings? = nil,
        hlgOOTF: HLGOOTFSettings? = nil
    ) {
        self.inputTransfer = inputTransfer
        self.outputTransfer = outputTransfer
        self.inputSpace = inputSpace
        self.outputSpace = outputSpace
        self.inputRange = inputRange
        self.outputRange = outputRange
        self.exposureStops = exposureStops
        self.rangeBitDepth = rangeBitDepth
        self.adaptation = adaptation
        self.inputGamma = inputGamma
        self.outputGamma = outputGamma
        self.cameraExposure = cameraExposure
        self.inputLogC = inputLogC
        self.outputLogC = outputLogC
        self.ascCDL = ascCDL
        self.sdrSaturation = sdrSaturation
        self.multitone = multitone
        self.blackGamma = blackGamma
        self.blackHighlight = blackHighlight
        self.knee = knee
        self.highlightGamut = highlightGamut
        self.gamutLimiter = gamutLimiter
        self.outputCodeUnits=outputCodeUnits
        self.displayConversion=displayConversion
        self.falseColour=falseColour
        self.finalOutput=finalOutput
        self.hlgOOTF=hlgOOTF
    }

    public var referencesARRIWideGamut3: Bool {
        inputSpace == .arriWideGamut3 || outputSpace == .arriWideGamut3
            || highlightGamut?.highlightSpace == .arriWideGamut3
            || gamutLimiter?.secondarySpace == .arriWideGamut3
    }

    public func withInputRange(_ range: SignalNormalization) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: range, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public var referencesBMDGen5:Bool {
        [inputTransfer,outputTransfer].contains { $0 == .blackmagicFilmGen5 || $0 == .blackmagicFilmGen5LUTCalcLegacy }
            || inputSpace == .blackmagicWideGamutGen5 || outputSpace == .blackmagicWideGamutGen5
            || highlightGamut?.highlightSpace == .blackmagicWideGamutGen5
            || gamutLimiter?.secondarySpace == .blackmagicWideGamutGen5
    }

    public var referencesCanonCLog2: Bool {
        [inputTransfer, outputTransfer].contains { $0 == .canonCLog2 || $0 == .canonCLog2LUTCalcLegacy }
            || inputSpace == .canonCinemaGamut || outputSpace == .canonCinemaGamut
            || highlightGamut?.highlightSpace == .canonCinemaGamut
            || gamutLimiter?.secondarySpace == .canonCinemaGamut
    }

    public var referencesCanonCLog3: Bool {
        [inputTransfer, outputTransfer].contains { $0 == .canonCLog3 }
    }

    public func withOutputRange(_ range: SignalNormalization) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: range,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withRangeBitDepth(_ depth: Int) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: depth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withAdaptation(_ method: ChromaticAdaptation) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: method, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withCameraExposure(_ camera: CameraExposureSettings?) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:camera,hlgOOTF:hlgOOTF)
    }

    public func withExposureStops(_ stops: Double) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: stops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure?.overridingExposureStops(stops),hlgOOTF:hlgOOTF)
    }

    /// Returns settings with the input transfer and primaries selected from
    /// the native algorithm catalog. A parameterized Gamma payload belongs to
    /// the transfer ID, so it is retained only when that ID remains selected.
    public func withInput(transfer: TransferID, space: ColorSpaceID) -> TransformSettings {
        TransformSettings(
            inputTransfer: transfer, outputTransfer: outputTransfer,
            inputSpace: space, outputSpace: outputSpace,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation,
            inputGamma: transfer == inputTransfer ? inputGamma : nil,
            outputGamma: outputGamma, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:transfer == inputTransfer ? inputLogC : nil,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withOutput(transfer: TransferID, space: ColorSpaceID) -> TransformSettings {
        TransformSettings(
            inputTransfer: inputTransfer, outputTransfer: transfer,
            inputSpace: inputSpace, outputSpace: space,
            inputRange: inputRange, outputRange: outputRange,
            exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma,
            outputGamma: transfer == outputTransfer ? outputGamma : nil, ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight?.rebasedForChanges(outputChanged: transfer != outputTransfer), knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:transfer == outputTransfer ? outputLogC : nil,cameraExposure:cameraExposure,hlgOOTF:transfer == outputTransfer ? hlgOOTF : nil)
    }

    public func withASCCDL(_ cdl: ASCCDLSettings?) -> TransformSettings {
        let changed=(ascCDL?.enabled ?? false) != (cdl?.enabled ?? false) || (0..<3).contains { c in
            (ascCDL?.slope[c] ?? 1) != (cdl?.slope[c] ?? 1) ||
            (ascCDL?.offset[c] ?? 0) != (cdl?.offset[c] ?? 0) ||
            (ascCDL?.power[c] ?? 1) != (cdl?.power[c] ?? 1)
        }
        return TransformSettings(inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace, inputRange: inputRange,
            outputRange: outputRange, exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma, ascCDL: cdl, sdrSaturation: sdrSaturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight?.rebasedForChanges(cdlChanged:changed), knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withSDRSaturation(_ saturation: SDRSaturationSettings?) -> TransformSettings {
        TransformSettings(inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace, inputRange: inputRange,
            outputRange: outputRange, exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma,
            ascCDL: ascCDL, sdrSaturation: saturation, multitone: multitone, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withMultitone(_ settings: MultitoneSettings?) -> TransformSettings {
        TransformSettings(inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace, inputRange: inputRange,
            outputRange: outputRange, exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma,
            ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: settings, blackGamma: blackGamma, blackHighlight: blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withBlackGamma(_ gamma: BlackGammaSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,
            inputSpace:inputSpace,outputSpace:outputSpace,inputRange:inputRange,outputRange:outputRange,
            exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,
            sdrSaturation:sdrSaturation,multitone:multitone,blackGamma:gamma,blackHighlight:blackHighlight, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withBlackHighlight(_ levels:BlackHighlightSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,
            inputSpace:inputSpace,outputSpace:outputSpace,inputRange:inputRange,outputRange:outputRange,
            exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,
            multitone:multitone,blackGamma:blackGamma,blackHighlight:levels, knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withKnee(_ knee:KneeSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,
            inputSpace:inputSpace,outputSpace:outputSpace,inputRange:inputRange,outputRange:outputRange,
            exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,
            multitone:multitone,blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withHighlightGamut(_ highlight:HighlightGamutSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,
            inputSpace:inputSpace,outputSpace:outputSpace,inputRange:inputRange,outputRange:outputRange,
            exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,
            multitone:multitone,blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlight,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withGamutLimiter(_ limiter:GamutLimiterSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,
            inputSpace:inputSpace,outputSpace:outputSpace,inputRange:inputRange,outputRange:outputRange,
            exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,
            multitone:multitone,blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,
            highlightGamut:highlightGamut,gamutLimiter:limiter,outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withOutputCodeUnits(_ policy:OutputCodeUnitPolicy)->TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,inputSpace:inputSpace,outputSpace:outputSpace,
            inputRange:inputRange,outputRange:outputRange,exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,multitone:multitone,
            blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:policy,displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withDisplayConversion(_ display:DisplayConversionSettings?)->TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,inputSpace:inputSpace,outputSpace:outputSpace,
            inputRange:inputRange,outputRange:outputRange,exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,multitone:multitone,
            blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,
            outputCodeUnits:outputCodeUnits,displayConversion:display,falseColour:falseColour,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withFalseColour(_ fc:FalseColourSettings?)->TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,inputSpace:inputSpace,outputSpace:outputSpace,
            inputRange:inputRange,outputRange:outputRange,exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,multitone:multitone,
            blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,
            outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:fc,finalOutput:finalOutput,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withFinalOutput(_ final:FinalOutputSettings?)->TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,inputSpace:inputSpace,outputSpace:outputSpace,
            inputRange:inputRange,outputRange:outputRange,exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,multitone:multitone,
            blackGamma:blackGamma,blackHighlight:blackHighlight,knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,
            outputCodeUnits:outputCodeUnits,displayConversion:displayConversion,falseColour:falseColour,finalOutput:final,inputLogC:inputLogC,outputLogC:outputLogC,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    public func withHLGOOTF(_ ootf: HLGOOTFSettings?) -> TransformSettings {
        TransformSettings(inputTransfer: inputTransfer, outputTransfer: outputTransfer,
            inputSpace: inputSpace, outputSpace: outputSpace, inputRange: inputRange,
            outputRange: outputRange, exposureStops: exposureStops, rangeBitDepth: rangeBitDepth,
            adaptation: adaptation, inputGamma: inputGamma, outputGamma: outputGamma,
            ascCDL: ascCDL, sdrSaturation: sdrSaturation, multitone: multitone,
            blackGamma: blackGamma, blackHighlight: blackHighlight, knee: knee,
            highlightGamut: highlightGamut, gamutLimiter: gamutLimiter,
            outputCodeUnits: outputCodeUnits, displayConversion: displayConversion,
            falseColour: falseColour, finalOutput: finalOutput, inputLogC: inputLogC,
            outputLogC: outputLogC, cameraExposure: cameraExposure, hlgOOTF: ootf)
    }

    public func withInputLogC(_ logC: ARRILogCSceneSettings?) -> TransformSettings {
        withLogC(input: logC, output: outputLogC)
    }
    public func withOutputLogC(_ logC: ARRILogCSceneSettings?) -> TransformSettings {
        withLogC(input: inputLogC, output: logC)
    }
    private func withLogC(input: ARRILogCSceneSettings?, output: ARRILogCSceneSettings?) -> TransformSettings {
        TransformSettings(inputTransfer:inputTransfer,outputTransfer:outputTransfer,inputSpace:inputSpace,outputSpace:outputSpace,
            inputRange:inputRange,outputRange:outputRange,exposureStops:exposureStops,rangeBitDepth:rangeBitDepth,adaptation:adaptation,
            inputGamma:inputGamma,outputGamma:outputGamma,ascCDL:ascCDL,sdrSaturation:sdrSaturation,multitone:multitone,
            blackGamma:blackGamma,blackHighlight:blackHighlight?.rebasedForChanges(outputChanged:output != outputLogC),
            knee:knee,highlightGamut:highlightGamut,gamutLimiter:gamutLimiter,outputCodeUnits:outputCodeUnits,
            displayConversion:displayConversion,falseColour:falseColour,finalOutput:finalOutput,inputLogC:input,outputLogC:output,cameraExposure:cameraExposure,hlgOOTF:hlgOOTF)
    }

    private enum CodingKeys: String, CodingKey {
        case cameraExposure, inputTransfer, outputTransfer, inputSpace, outputSpace
        case inputRange, outputRange, exposureStops, rangeBitDepth, adaptation
        case inputLogC, outputLogC
        case inputGamma, outputGamma, ascCDL, sdrSaturation, multitone, blackGamma, blackHighlight, knee, highlightGamut, gamutLimiter, outputCodeUnits, displayConversion, falseColour, finalOutput, hlgOOTF
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            inputTransfer: try container.decode(TransferID.self, forKey: .inputTransfer),
            outputTransfer: try container.decode(TransferID.self, forKey: .outputTransfer),
            inputSpace: try container.decode(ColorSpaceID.self, forKey: .inputSpace),
            outputSpace: try container.decode(ColorSpaceID.self, forKey: .outputSpace),
            inputRange: try container.decode(SignalNormalization.self, forKey: .inputRange),
            outputRange: try container.decode(SignalNormalization.self, forKey: .outputRange),
            exposureStops: try container.decode(Double.self, forKey: .exposureStops),
            rangeBitDepth: try container.decode(Int.self, forKey: .rangeBitDepth),
            adaptation: try container.decodeIfPresent(ChromaticAdaptation.self, forKey: .adaptation) ?? .cieCAT02,
            inputGamma: try container.decodeIfPresent(ParameterizedGammaSettings.self, forKey: .inputGamma),
            outputGamma: try container.decodeIfPresent(ParameterizedGammaSettings.self, forKey: .outputGamma),
            ascCDL: try container.decodeIfPresent(ASCCDLSettings.self, forKey: .ascCDL),
            sdrSaturation: try container.decodeIfPresent(SDRSaturationSettings.self, forKey: .sdrSaturation),
            multitone: try container.decodeIfPresent(MultitoneSettings.self, forKey: .multitone),
            blackGamma: try container.decodeIfPresent(BlackGammaSettings.self, forKey: .blackGamma),
            blackHighlight: try container.decodeIfPresent(BlackHighlightSettings.self, forKey: .blackHighlight),
            knee: try container.decodeIfPresent(KneeSettings.self, forKey: .knee),
            highlightGamut: try container.decodeIfPresent(HighlightGamutSettings.self, forKey: .highlightGamut),
            gamutLimiter: try container.decodeIfPresent(GamutLimiterSettings.self, forKey: .gamutLimiter),
            outputCodeUnits:try container.decodeIfPresent(OutputCodeUnitPolicy.self,forKey:.outputCodeUnits) ?? .completeV2,
            displayConversion:try container.decodeIfPresent(DisplayConversionSettings.self,forKey:.displayConversion),
            falseColour:try container.decodeIfPresent(FalseColourSettings.self,forKey:.falseColour),
            finalOutput:try container.decodeIfPresent(FinalOutputSettings.self,forKey:.finalOutput),
            inputLogC:try container.decodeIfPresent(ARRILogCSceneSettings.self,forKey:.inputLogC),
            outputLogC:try container.decodeIfPresent(ARRILogCSceneSettings.self,forKey:.outputLogC),
            cameraExposure:try container.decodeIfPresent(CameraExposureSettings.self,forKey:.cameraExposure),
            hlgOOTF:try container.decodeIfPresent(HLGOOTFSettings.self,forKey:.hlgOOTF)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputTransfer, forKey: .inputTransfer)
        try container.encode(outputTransfer, forKey: .outputTransfer)
        try container.encode(inputSpace, forKey: .inputSpace)
        try container.encode(outputSpace, forKey: .outputSpace)
        try container.encode(inputRange, forKey: .inputRange)
        try container.encode(outputRange, forKey: .outputRange)
        try container.encode(exposureStops, forKey: .exposureStops)
        try container.encode(rangeBitDepth, forKey: .rangeBitDepth)
        if adaptation != .cieCAT02 {
            try container.encode(adaptation, forKey: .adaptation)
        }
        try container.encodeIfPresent(cameraExposure, forKey: .cameraExposure)
        try container.encodeIfPresent(inputLogC, forKey: .inputLogC)
        try container.encodeIfPresent(outputLogC, forKey: .outputLogC)
        try container.encodeIfPresent(inputGamma, forKey: .inputGamma)
        try container.encodeIfPresent(outputGamma, forKey: .outputGamma)
        try container.encodeIfPresent(ascCDL, forKey: .ascCDL)
        try container.encodeIfPresent(sdrSaturation, forKey: .sdrSaturation)
        try container.encodeIfPresent(multitone, forKey: .multitone)
        try container.encodeIfPresent(blackGamma, forKey: .blackGamma)
        try container.encodeIfPresent(blackHighlight, forKey: .blackHighlight)
        try container.encodeIfPresent(knee, forKey: .knee)
        try container.encodeIfPresent(highlightGamut, forKey: .highlightGamut)
        try container.encodeIfPresent(gamutLimiter, forKey: .gamutLimiter)
        if requiresOutputCodeUnitIdentity {try container.encode(outputCodeUnits,forKey:.outputCodeUnits)}
        try container.encodeIfPresent(displayConversion,forKey:.displayConversion)
        try container.encodeIfPresent(falseColour,forKey:.falseColour)
        try container.encodeIfPresent(finalOutput,forKey:.finalOutput)
        try container.encodeIfPresent(hlgOOTF,forKey:.hlgOOTF)
    }

    public func validateParameterizedTransfers() throws {
        if let cameraExposure {
            try cameraExposure.validate()
            guard cameraExposure.stopCorrection.bitPattern == exposureStops.bitPattern else {throw CameraExposureError.stateMismatch}
        }
        if inputTransfer.requiresLogCSceneSettings {
            guard let inputLogC else { throw TransformSettingsError.missingInputLogC }
            guard inputLogC.algorithm.transferID == inputTransfer else { throw TransformSettingsError.logCAlgorithmMismatch }
        } else if inputLogC != nil { throw TransformSettingsError.unexpectedInputLogC }
        if outputTransfer.requiresLogCSceneSettings {
            guard let outputLogC else { throw TransformSettingsError.missingOutputLogC }
            guard outputLogC.algorithm.transferID == outputTransfer else { throw TransformSettingsError.logCAlgorithmMismatch }
        } else if outputLogC != nil { throw TransformSettingsError.unexpectedOutputLogC }

        if let hlgOOTF, hlgOOTF.enabled {
            guard outputTransfer == .rec2100HLG else {
                throw TransformSettingsError.invalidHLGOOTFTransfer
            }
            // The composed plan accepts either the persisted nits form or the
            // normalized-by-1000 form.  Both are converted at the OETF
            // boundary below; the explicit display stage remains in its
            // declared unit for tracing and downstream display-domain work.
            _ = try hlgOOTF.makeKernel()
        }

        switch (inputTransfer, inputGamma) {
        case (.parameterizedGamma, .some): break
        case (.parameterizedGamma, .none): throw TransformSettingsError.missingInputGamma
        case (_, .some): throw TransformSettingsError.unexpectedInputGamma
        default: break
        }
        switch (outputTransfer, outputGamma) {
        case (.parameterizedGamma, .some): break
        case (.parameterizedGamma, .none): throw TransformSettingsError.missingOutputGamma
        case (_, .some): throw TransformSettingsError.unexpectedOutputGamma
        default: break
        }
    }
}

public enum TransformSettingsError: Error, Equatable, Sendable {
    case missingInputLogC, missingOutputLogC, unexpectedInputLogC, unexpectedOutputLogC, logCAlgorithmMismatch
    case missingInputGamma
    case missingOutputGamma
    case unexpectedInputGamma
    case unexpectedOutputGamma
    case invalidHLGOOTFTransfer
    case invalidHLGOOTFScale
}

public enum PlanError: Error, Equatable, Sendable {
    case invalidExposure
    case numeric(stageID: Int, sampleIndex: Int?)
}

public struct StageValue: Sendable {
    public let id: Int
    public let input: RGB64
    public let output: RGB64
    public let inputUnit: SignalUnit
    public let outputUnit: SignalUnit
    public let inputSpace: ColorSpaceID?
    public let outputSpace: ColorSpaceID?
    public let inputDisplayGamut:DisplayGamut?
    public let outputDisplayGamut:DisplayGamut?
    public let falseColourBand:FalseColourBand?
}

public struct StageTrace: Sendable {
    public let output: RGB64
    public let stages: [StageValue]
}

public struct TransformPlan: Sendable {
    public let settings: TransformSettings
    public var planVersion: String {
        basePlanVersion + cameraPlanIdentity + logCPlanIdentity + (settings.referencesARRIWideGamut3 ? "+gamut:arri.awg3.v1" : "") + (settings.finalOutput?.enabled == true ? "+"+settings.finalOutput!.algorithm.rawValue : "") + (settings.falseColour?.isActive == true ? "+"+settings.falseColour!.algorithm.rawValue : "") + (settings.requiresOutputCodeUnitIdentity ? "+"+settings.outputCodeUnits.rawValue : "") + (settings.ascCDL?.enabled == true ? "+asccdl-lutcalc-working-v1" : "")
            + (settings.sdrSaturation?.enabled == true ? "+sdrsat-lutcalc-output-v1" : "")
            + (settings.multitone?.enabled == true ? "+multitone-lutcalc-working-v1" : "")
            + (settings.blackGamma?.enabled == true ? "+black-gamma-" + settings.blackGamma!.algorithm.rawValue : "")
            + (settings.displayConversion?.enabled == true ? "+"+settings.displayConversion!.algorithm.rawValue : "")
            + (settings.gamutLimiter?.enabled == true ? "+gamut-limiter-lutcalc-chroma-span-v1" : "")
            + (settings.highlightGamut?.enabled == true ? "+highlight-gamut-lutcalc-output-blend-v1" : "")
            + (settings.knee?.enabled == true ? "+knee-lutcalc-output-hermite-v1" : "")
            + (settings.blackHighlight?.enabled == true ? "+black-highlight-lutcalc-legal-affine-v1" : "")
            + (settings.hlgOOTF?.enabled == true ? "+"+settings.hlgOOTF!.algorithm.rawValue : "")
    }
    private var cameraPlanIdentity: String {
        guard let c=settings.cameraExposure else {return ""}
        return "+"+c.algorithm+":"+c.profileID+":ISO"+String(c.recordedISO)+":"+c.source.rawValue+":"+c.inputPolicy.rawValue
    }
    private var logCPlanIdentity: String {
        let input = settings.inputLogC.map { "+input-logc:" + $0.algorithm.rawValue + ":EI" + String($0.exposureIndex) } ?? ""
        let output = settings.outputLogC.map { "+output-logc:" + $0.algorithm.rawValue + ":EI" + String($0.exposureIndex) } ?? ""
        return input + output
    }
    private var basePlanVersion: String {
        if [.nikonNLog, .nikonNLogLUTCalcLegacy, .cineon, .cineonLUTCalcLegacy].contains(settings.inputTransfer) ||
            [.nikonNLog, .nikonNLogLUTCalcLegacy, .cineon, .cineonLUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-camera-transfer-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if [.redLogFilm, .redLogFilmLUTCalcLegacy].contains(settings.inputTransfer) ||
            [.redLogFilm, .redLogFilmLUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-red-logfilm-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .redLog3G10LUTCalcLegacy || settings.outputTransfer == .redLog3G10LUTCalcLegacy {
            return "analytic-red-log3g10-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.referencesBMDGen5 {
            return "bmd-gen5-plan-v1:"+settings.inputTransfer.rawValue+":"+settings.outputTransfer.rawValue+":gamut:"+ColorSpaceID.blackmagicWideGamutGen5.rawValue
        }
        if settings.referencesCanonCLog3 {
            return "canon-clog3-plan-v1:"+settings.inputTransfer.rawValue+":"+settings.outputTransfer.rawValue+":gamut:"+ColorSpaceID.canonCinemaGamut.rawValue
        }
        if settings.referencesCanonCLog2 {
            return "canon-clog2-plan-v1:"+settings.inputTransfer.rawValue+":"+settings.outputTransfer.rawValue+":gamut:"+ColorSpaceID.canonCinemaGamut.rawValue
        }
        if settings.inputTransfer == .canonCLogLUTCalcLegacy || settings.outputTransfer == .canonCLogLUTCalcLegacy {
            return "analytic-canon-clog-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .blackmagicPocketFilmLUTCalcLegacy || settings.outputTransfer == .blackmagicPocketFilmLUTCalcLegacy {
            return "analytic-bmd-pocket-film-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if [.blackmagicFilmLUTCalcLegacy, .blackmagicFilm4kLUTCalcLegacy, .blackmagicFilm46kLUTCalcLegacy].contains(settings.inputTransfer) ||
            [.blackmagicFilmLUTCalcLegacy, .blackmagicFilm4kLUTCalcLegacy, .blackmagicFilm46kLUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-bmd-film-family-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if [.bolexLogLUTCalcLegacy, .panalogLUTCalcLegacy, .djiX5LogLUTCalcLegacy, .goProProtuneLUTCalcLegacy].contains(settings.inputTransfer) ||
            [.bolexLogLUTCalcLegacy, .panalogLUTCalcLegacy, .djiX5LogLUTCalcLegacy, .goProProtuneLUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-legacy-registered-log-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .daVinciIntermediateLUTCalcLegacy || settings.outputTransfer == .daVinciIntermediateLUTCalcLegacy {
            return "analytic-davinci-intermediate-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .djiX3DLogLUTCalcLegacy || settings.outputTransfer == .djiX3DLogLUTCalcLegacy {
            return "analytic-dji-x3-dlog-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer.requiresLogCSceneSettings || settings.outputTransfer.requiresLogCSceneSettings {
            return "published-logc-scene-plan-v1"
        }

        if settings.inputTransfer == .fujifilmFLog2LUTCalcLegacy || settings.outputTransfer == .fujifilmFLog2LUTCalcLegacy {
            return "minimal-flog2-legacy-v1"
        }
        if settings.inputTransfer == .fujifilmFLogLUTCalcLegacy || settings.outputTransfer == .fujifilmFLogLUTCalcLegacy {
            return "analytic-flog-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .fujifilmFLog2 || settings.outputTransfer == .fujifilmFLog2 {
            if settings.inputSpace == .fujifilmFGamutC || settings.outputSpace == .fujifilmFGamutC {
                return "minimal-flog2c-v1"
            }
            return "minimal-flog2-v1"
        }
        if settings.inputTransfer == .acesCCT || settings.outputTransfer == .acesCCT {
            return "minimal-acescct-v1"
        }
        if settings.inputTransfer == .acesCC || settings.outputTransfer == .acesCC {
            return "minimal-acescc-v1"
        }
        if settings.inputTransfer == .acesProxy10 || settings.outputTransfer == .acesProxy10 {
            return "minimal-acesproxy10-v1"
        }
        if settings.inputTransfer == .acesProxy12 || settings.outputTransfer == .acesProxy12 {
            return "minimal-acesproxy12-v1"
        }
        if settings.inputTransfer == .insta360ILog || settings.outputTransfer == .insta360ILog {
            return "minimal-ilog-v1"
        }
        if settings.inputTransfer == .xiaomiMiLog || settings.outputTransfer == .xiaomiMiLog {
            return "minimal-milog-v1"
        }
        if settings.inputTransfer == .leicaLLog || settings.outputTransfer == .leicaLLog {
            return "minimal-llog-v1"
        }
        if settings.inputTransfer == .kineLog3 || settings.outputTransfer == .kineLog3 {
            return "minimal-kinelog3-v1"
        }
        if settings.inputTransfer == .appleLog2 || settings.outputTransfer == .appleLog2 {
            return "minimal-applelog2-v1"
        }
        if settings.inputTransfer == .appleLogOriginal || settings.outputTransfer == .appleLogOriginal {
            return "minimal-applelog-v1"
        }
        if settings.inputTransfer == .panasonicVLog || settings.outputTransfer == .panasonicVLog {
            return "minimal-vlog-v1"
        }
        if settings.inputTransfer == .arriLogC4 || settings.outputTransfer == .arriLogC4 {
            return "minimal-logc4-v1"
        }
        if settings.inputTransfer == .sonySLog3 || settings.outputTransfer == .sonySLog3 ||
            settings.inputTransfer == .sonySLog3LUTCalcLegacy ||
            settings.outputTransfer == .sonySLog3LUTCalcLegacy {
            return "minimal-slog3-v1"
        }
        if [.sonySLog2, .sonySLog2LUTCalcLegacy].contains(settings.inputTransfer) ||
            [.sonySLog2, .sonySLog2LUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-slog2-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if [.sonySLog, .sonySLogLUTCalcLegacy].contains(settings.inputTransfer) ||
            [.sonySLog, .sonySLogLUTCalcLegacy].contains(settings.outputTransfer) {
            return "analytic-slog-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .rec709LUTCalcLegacy || settings.outputTransfer == .rec709LUTCalcLegacy {
            return "minimal-rec709-v1"
        }
        if settings.inputTransfer == .rec2020TenBit || settings.outputTransfer == .rec2020TenBit {
            return "minimal-rec2020-10bit-v1"
        }
        if settings.inputTransfer == .rec2020TwelveBit || settings.outputTransfer == .rec2020TwelveBit {
            return "analytic-rec2020-12bit-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .srgbW3CExtended || settings.outputTransfer == .srgbW3CExtended ||
            settings.inputTransfer == .srgbLUTCalcLegacy || settings.outputTransfer == .srgbLUTCalcLegacy {
            return "minimal-srgb-v1"
        }
        if settings.inputTransfer == .rec2100HLG || settings.outputTransfer == .rec2100HLG {
            return "minimal-rec2100-hlg-v1"
        }
        if settings.inputTransfer == .rec2100PQ || settings.outputTransfer == .rec2100PQ {
            return "minimal-rec2100-pq-v1"
        }
        if settings.inputTransfer == .bt1886 || settings.outputTransfer == .bt1886 {
            return "minimal-bt1886-eotf-v1"
        }
        if settings.inputTransfer == .cieLStar || settings.outputTransfer == .cieLStar {
            return "minimal-cie-lstar-v1"
        }
        if settings.inputTransfer == .proPhoto || settings.outputTransfer == .proPhoto {
            return "minimal-prophoto-v1"
        }
        if settings.inputTransfer == .ituProposal400 || settings.outputTransfer == .ituProposal400 ||
            settings.inputTransfer == .ituProposal800 || settings.outputTransfer == .ituProposal800 {
            return "analytic-itu-proposal-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if Self.isBBCGamma(settings.inputTransfer) || Self.isBBCGamma(settings.outputTransfer) {
            return "minimal-bbc-gamma-v1"
        }
        if Self.isBBCWHP283(settings.inputTransfer) || Self.isBBCWHP283(settings.outputTransfer) {
            return "minimal-bbc-whp283-v1"
        }
        if Self.isConventionalGamma(settings.inputTransfer) || Self.isConventionalGamma(settings.outputTransfer) {
            return "legacy-conventional-gamma-v1"
        }
        if settings.inputTransfer == .parameterizedGamma || settings.outputTransfer == .parameterizedGamma {
            return "parameterized-gamma-settings-v1"
        }
        if settings.inputTransfer == .nullLUTCalcLegacy || settings.outputTransfer == .nullLUTCalcLegacy {
            if settings.inputTransfer == .nullLUTCalcLegacy && settings.outputTransfer == .nullLUTCalcLegacy {
                return "analytic-null-legacy-v1"
            }
            return "analytic-null-legacy-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        if settings.inputTransfer == .linearScene || settings.outputTransfer == .linearScene {
            if settings.inputTransfer == .linearScene && settings.outputTransfer == .linearScene {
                return "minimal-linear-scene-v1"
            }
            return "minimal-linear-scene-v1:" + settings.inputTransfer.rawValue + ":" + settings.outputTransfer.rawValue
        }
        return "minimal-dlog2-v1"
    }

    private static func isConventionalGamma(_ id: TransferID) -> Bool {
        switch id {
        case .gamma15, .gamma16, .gamma17, .gamma18, .gamma19, .gamma20,
             .gamma21, .gamma22, .gamma23, .gamma24, .gamma25, .gamma26:
            return true
        default:
            return false
        }
    }

    private static func isBBCGamma(_ id: TransferID) -> Bool {
        switch id {
        case .bbc04, .bbc05, .bbc06: true
        default: false
        }
    }

    private static func isBBCWHP283(_ id: TransferID) -> Bool {
        switch id {
        case .bbcWHP283400, .bbcWHP283800: true
        default: false
        }
    }
    private let inputToWork: Matrix3x3
    private let workToOutput: Matrix3x3
    private let workingSpace: ColorSpaceID
    private let ascCDLKernel: LegacyASCCDL?
    private let sdrSaturationKernel: LegacySDRSaturation?
    private let multitoneKernel: LegacyMultitone?
    private let blackGammaKernel: LegacyBlackGamma?
    private let blackHighlightKernel: LegacyBlackHighlight?
    private let exposureGain: Double
    private let videoRange: CodeRange
    private let inputLogC: ARRILogCCompact?
    private let inputParameterizedGamma: ParameterizedGammaTransfer?
    private let outputEncoder:NativeOutputEncoder
    private let kneeKernel:LegacyKnee?
    private let highlightGamutKernel:LegacyHighlightGamut?
    private let gamutLimiterKernel:LegacyGamutLimiter?
    private let displayKernel:LegacyDisplayConversion?
    private let falseColourKernel:LegacyFalseColour?
    private let finalOutputKernel:LegacyFinalOutput?
    private let hlgOOTFKernel: HLGOOTF?

    private func decodeLogC(_ value: Double) throws -> Double {
        guard let inputLogC else { throw NumericError.invalidDomain }
        return try inputLogC.decode(value)
    }
    private func decodeParameterizedGamma(_ value: Double) throws -> Double {
        guard let transfer = inputParameterizedGamma else { throw NumericError.invalidDomain }
        return try LinearScale.legacyToScene(transfer.decodeLegalToLegacy(value))
    }

    public init(settings: TransformSettings) throws {
        try settings.validateParameterizedTransfers()
        let gain = pow(2.0, settings.exposureStops)
        guard settings.exposureStops.isFinite, gain.isFinite, gain > 0 else { throw PlanError.invalidExposure }
        self.settings = settings
        exposureGain = gain
        inputLogC = try settings.inputLogC?.makeTransfer()
        inputParameterizedGamma = try settings.inputGamma?.makeTransfer()
        let encoder=try NativeOutputEncoder(settings:settings)
        outputEncoder=encoder
        let knee=try settings.knee.flatMap { $0.enabled ? try LegacyKnee(settings:$0,cdl:settings.ascCDL,
            encodeLegacyToLegal:encoder.encodeLegacyToLegal) : nil }
        kneeKernel=knee
        videoRange = try CodeRange.videoRGB(bitDepth: settings.rangeBitDepth)
        multitoneKernel = try settings.multitone.flatMap {
            $0.enabled ? try LegacyMultitone(settings:$0,outputPrimaries:settings.outputSpace.primaries,adaptation:settings.adaptation) : nil
        }
        sdrSaturationKernel = try settings.sdrSaturation.flatMap {
            $0.enabled ? try LegacySDRSaturation(settings: $0, outputPrimaries: settings.outputSpace.primaries) : nil
        }
        highlightGamutKernel=try settings.highlightGamut.flatMap {
            $0.enabled ? try LegacyHighlightGamut(settings:$0,basePrimaries:settings.outputSpace.primaries,adaptation:settings.adaptation) : nil
        }
        finalOutputKernel=try settings.finalOutput.flatMap {$0.enabled ? try LegacyFinalOutput(settings:$0,outputRange:settings.outputRange,
            hdrOutputActive:settings.outputTransfer == .rec2100PQ || settings.outputTransfer == .rec2100HLG,
            displayConversionActive:settings.displayConversion?.enabled == true) : nil}
        falseColourKernel=try settings.falseColour.flatMap {$0.isActive ? try LegacyFalseColour(settings:$0) : nil}
        displayKernel=try settings.displayConversion.flatMap {$0.enabled ? try LegacyDisplayConversion(settings:$0) : nil}
        hlgOOTFKernel = try settings.hlgOOTF.flatMap { $0.enabled ? try $0.makeKernel() : nil }
        gamutLimiterKernel=try settings.gamutLimiter.flatMap {
            $0.enabled ? try LegacyGamutLimiter(settings:$0,outputSpace:settings.outputSpace,adaptation:settings.adaptation) : nil
        }
        ascCDLKernel = try settings.ascCDL.flatMap { $0.enabled ? try LegacyASCCDL(settings: $0) : nil }
        let levels=settings.blackHighlight
        let gamma=settings.blackGamma
        if levels?.enabled == true && (levels!.doBlack || levels!.doHigh) || gamma?.enabled == true {
            let sop=try settings.ascCDL.flatMap { $0.enabled ? try LegacyASCCDL(settings:$0) : nil }
            func anchor(_ value:Double)throws->Double {
                let gray=try RGB64(value,value,value)
                let adjusted=try sop?.evaluateScene(gray,applySaturation:false) ?? gray
                let encoded=try RGB64(encoder.encodeScene(adjusted.r,knee:knee),encoder.encodeScene(adjusted.g,knee:knee),encoder.encodeScene(adjusted.b,knee:knee))
                return 0.2126*encoded.r+0.7152*encoded.g+0.0722*encoded.b
            }
            let prepared:LegacyBlackHighlight?
            if let levels,levels.enabled && (levels.doBlack || levels.doHigh) {
                prepared=try LegacyBlackHighlight(settings:levels,blackDefault:anchor(0),
                    highDefault:anchor(levels.highReferenceScene),
                    legalToNativeScale:encoder.legalScale,
                    legalToNativeOffset:encoder.legalOffset)
            }else{prepared=nil}
            blackHighlightKernel=prepared
            if let gamma,gamma.enabled {
                func mappedAnchor(_ x:Double)throws->Double {
                    let a=try anchor(x)
                    return try prepared?.evaluate(a) ?? a
                }
                blackGammaKernel=try LegacyBlackGamma(settings:gamma,black:mappedAnchor(0),
                    lower:mappedAnchor(0.18*pow(2,gamma.upperStops-gamma.featherStops)),
                    upper:mappedAnchor(0.18*pow(2,gamma.upperStops)))
            }else{blackGammaKernel=nil}
        }else{blackGammaKernel=nil;blackHighlightKernel=nil}
        if settings.inputSpace == settings.outputSpace && ascCDLKernel == nil && multitoneKernel == nil && highlightGamutKernel == nil && falseColourKernel == nil {
            workingSpace = settings.inputSpace
            inputToWork = .identity
            workToOutput = .identity
        } else {
            workingSpace = .sonySGamut3Cine
            inputToWork = highlightGamutKernel != nil && settings.inputSpace == .sonySGamut3Cine ? .identity : try ColorPrimaries.conversion(
                from: settings.inputSpace.primaries, to: .sonySGamut3Cine, adaptation: settings.adaptation
            )
            workToOutput = try ColorPrimaries.conversion(
                from: .sonySGamut3Cine, to: settings.outputSpace.primaries, adaptation: settings.adaptation
            )
        }
    }

    public func evaluate(_ input: RGB64, sampleIndex: Int? = nil) throws -> RGB64 {
        try run(input, sampleIndex: sampleIndex, captureTrace: false).output
    }

    public func trace(_ input: RGB64, sampleIndex: Int? = nil) throws -> StageTrace {
        try run(input, sampleIndex: sampleIndex, captureTrace: true)
    }

    /// Old oneDCalc applies per-channel SOP and skips colourspace/saturation.
    public func evaluateIndependentChannels(_ input: RGB64, sampleIndex: Int? = nil) throws -> RGB64 {
        guard settings.inputSpace == settings.outputSpace, sdrSaturationKernel == nil, multitoneKernel == nil, highlightGamutKernel == nil, gamutLimiterKernel == nil, falseColourKernel == nil else { throw NumericError.invalidDomain }
        return try run(input, sampleIndex: sampleIndex, captureTrace: false, independentChannels: true).output
    }

    private func run(_ input: RGB64, sampleIndex: Int?, captureTrace: Bool,
                     independentChannels: Bool = false) throws -> StageTrace {
        var current = input
        var unit: SignalUnit = settings.inputRange == .data ? .encodedData : .encodedVideo
        var colorSpace: ColorSpaceID? = settings.inputSpace
        var stages: [StageValue] = []
        var secondaryScene:RGB64?
        var falseColourBand:FalseColourBand?
        var displayGamut:DisplayGamut?
        let finalSpace:ColorSpaceID? = displayKernel != nil && !independentChannels ? settings.displayConversion!.outputGamut.colorSpaceID : settings.outputSpace
        if captureTrace { stages.reserveCapacity(7 + (ascCDLKernel == nil ? 0 : 1) + (sdrSaturationKernel == nil ? 0 : 1) + (multitoneKernel == nil ? 0 : 1) + (blackGammaKernel == nil ? 0 : 1) + (blackHighlightKernel == nil ? 0 : 1)) }

        func step(_ id: Int, to nextUnit: SignalUnit, space nextSpace: ColorSpaceID?, _ operation: (RGB64) throws -> RGB64) throws {
            let before = current
            do {
                current = try operation(before)
            } catch {
                throw PlanError.numeric(stageID: id, sampleIndex: sampleIndex)
            }
            if captureTrace {
                stages.append(StageValue(
                    id: id, input: before, output: current,
                    inputUnit: unit, outputUnit: nextUnit,
                    inputSpace: colorSpace, outputSpace: nextSpace,
                    inputDisplayGamut:id == 16 ? settings.displayConversion?.baseGamut : displayGamut,
                    outputDisplayGamut:id == 18 ? nil : id == 16 ? (independentChannels ? settings.displayConversion?.baseGamut : settings.displayConversion?.outputGamut) : displayGamut,
                    falseColourBand:falseColourBand
                ))
            }
            unit = nextUnit
            colorSpace = nextSpace
            if id == 16 {displayGamut=independentChannels ? settings.displayConversion?.baseGamut : settings.displayConversion?.outputGamut}
        }

        try step(1, to: .encodedData, space: settings.inputSpace) { input in
            if settings.inputRange == .data { return input }
            return try RGB64(
                videoRange.videoToData(input.r),
                videoRange.videoToData(input.g),
                videoRange.videoToData(input.b)
            )
        }
        try step(2, to: .sceneReflectance, space: settings.inputSpace) { input in
            func decode(_ value: Double) throws -> Double {
                return switch settings.inputTransfer {
                case .linearScene: value
                case .nullLUTCalcLegacy:
                    try LinearScale.legacyToScene(NullTransfer.decodeDataToLegacy(value))
                case .djiDLog2: try DLog2.decodeDataToScene(value)
                case .srgbW3CExtended: try SRGBTransfer.decode(value, variant: .w3cExtended)
                case .srgbLUTCalcLegacy: try LinearScale.legacyToScene(
                    SRGBTransfer.decode(value, variant: .lutcalcLegacy))
                case .rec709LUTCalcLegacy: try LinearScale.legacyToScene(
                    Rec709Transfer.decodeLegacy(value))
                case .rec2020TenBit: try Rec2020TenBitTransfer.decodeDataToScene(value)
                case .rec2020TwelveBit: try LinearScale.legacyToScene(Rec2020TwelveBitTransfer.decodeDataToLegacy(value))
                case .cineon: try CineonTransfer.decodeDataToScene(value)
                case .cineonLUTCalcLegacy: try LinearScale.legacyToScene(CineonTransfer.decodeDataToLegacy(value))
                case .redLogFilm: try REDLogFilmTransfer.decodeDataToScene(value)
                case .redLogFilmLUTCalcLegacy: try LinearScale.legacyToScene(REDLogFilmTransfer.decodeDataToLegacy(value))
                case .redLog3G10LUTCalcLegacy:
                    try LinearScale.legacyToScene(REDLog3G10Transfer.decodeDataToLegacy(value))
                case .sonySLog3: try SLog3Transfer.decodeSonyDataToScene(value)
                case .sonySLog3LUTCalcLegacy: try LinearScale.legacyToScene(
                    SLog3Transfer.decodeLegacyDataToLegacy(value))
                case .sonySLog2: try SonyLegacyLogTransfer.decodeDataToSLog2(value)
                case .sonySLog2LUTCalcLegacy: try LinearScale.legacyToScene(
                    SonyLegacyLogTransfer.decodeDataToSLog2Legacy(value))
                case .sonySLog: try SonyLegacyLogTransfer.decodeDataToSLog(value)
                case .sonySLogLUTCalcLegacy: try LinearScale.legacyToScene(
                    SonyLegacyLogTransfer.decodeDataToSLogLegacy(value))
                case .nikonNLog: try NikonNLogTransfer.decodeDataToScene(value)
                case .nikonNLogLUTCalcLegacy: try LinearScale.legacyToScene(NikonNLogTransfer.decodeDataToLegacy(value))
                case .arriLogCSUP2Scene, .arriLogCSUP3Scene: try decodeLogC(value)
                case .arriLogC4: try LogC4Transfer.decodeDataToScene(value)
                case .blackmagicFilmGen5: try BMDGen5Transfer.decodeDataToScene(value)
                case .blackmagicFilmGen5LUTCalcLegacy: try LinearScale.legacyToScene(BMDGen5Transfer.decodeLegacyDataToLegacy(value))
                case .canonCLog2: try CanonCLog2Transfer.decodeDataToScene(value)
                case .canonCLog2LUTCalcLegacy: try LinearScale.legacyToScene(CanonCLog2Transfer.decodeLegacyDataToLegacy(value))
                case .canonCLog3: try CanonCLog3Transfer.decodeDataToScene(value)
                case .canonCLogLUTCalcLegacy: try LinearScale.legacyToScene(CanonCLogTransfer.decodeDataToLegacy(value))
                case .blackmagicPocketFilmLUTCalcLegacy:
                    try LinearScale.legacyToScene(BMDPocketFilmTransfer.decodeDataToLegacy(value))
                case .blackmagicFilmLUTCalcLegacy:
                    try LinearScale.legacyToScene(BMDLegacyFilmTransfer.decodeDataToLegacy(value, variant: .film))
                case .blackmagicFilm4kLUTCalcLegacy:
                    try LinearScale.legacyToScene(BMDLegacyFilmTransfer.decodeDataToLegacy(value, variant: .film4k))
                case .blackmagicFilm46kLUTCalcLegacy:
                    try LinearScale.legacyToScene(BMDLegacyFilmTransfer.decodeDataToLegacy(value, variant: .film46k))
                case .bolexLogLUTCalcLegacy:
                    try LinearScale.legacyToScene(LegacyRegisteredLogTransfer.decodeDataToLegacy(value, variant: .bolex))
                case .panalogLUTCalcLegacy:
                    try LinearScale.legacyToScene(LegacyRegisteredLogTransfer.decodeDataToLegacy(value, variant: .panalog))
                case .djiX5LogLUTCalcLegacy:
                    try LinearScale.legacyToScene(LegacyRegisteredLogTransfer.decodeDataToLegacy(value, variant: .djiX5))
                case .goProProtuneLUTCalcLegacy:
                    try LinearScale.legacyToScene(LegacyRegisteredLogTransfer.decodeDataToLegacy(value, variant: .protune))
                case .djiX3DLogLUTCalcLegacy:
                    try LinearScale.legacyToScene(DJIX3DLogTransfer.decodeDataToLegacy(value))
                case .daVinciIntermediateLUTCalcLegacy:
                    try LinearScale.legacyToScene(DaVinciIntermediateTransfer.decodeDataToLegacy(value))
                case .panasonicVLog: try VLogTransfer.decodeDataToScene(value)
                case .fujifilmFLog2: try FLog2Transfer.decodeDataToScene(value)
                case .fujifilmFLog2LUTCalcLegacy: try LinearScale.legacyToScene(
                    FLog2Transfer.decodeLegacyDataToLegacy(value))
                case .fujifilmFLogLUTCalcLegacy:
                    try LinearScale.legacyToScene(FLogTransfer.decodeDataToLegacy(value))
                case .acesCCT: try ACESCCTTransfer.decodeCCTToLinearAP1(value)
                case .acesCC: try ACESCCTransfer.decodeCCToLinearAP1(value)
                case .acesProxy10: try ACESProxyTransfer.ten.decodeDataToLinearAP1(value)
                case .acesProxy12: try ACESProxyTransfer.twelve.decodeDataToLinearAP1(value)
                case .insta360ILog: try ILogTransfer.decodeDataToScene(value)
                case .xiaomiMiLog: try MiLogTransfer.decodeDataToScene(value)
                case .leicaLLog: try LeicaLLogTransfer.decodeDataToScene(value)
                case .kineLog3: try KineLog3Transfer.decodeDataToScene(value)
                case .appleLogOriginal, .appleLog2: try AppleLogTransfer.decodeDataToScene(value)
                case .rec2100HLG: try HLGTransfer.decodeDataToScene(value)
                case .rec2100PQ: try PQTransfer.decodeDataToNormalizedLuminance(value)
                // BT.1886 input is a display signal; decode it to normalized
                // luminance before the shared plan stages.
                case .bt1886: try BT1886Transfer.encodeDisplayToLuminance(value)
                case .cieLStar: try LinearScale.legacyToScene(CIELStarTransfer.decodeDataToLegacy(value))
                case .proPhoto: try LinearScale.legacyToScene(ProPhotoTransfer.decodeDataToLegacy(value))
                case .bbc04: try LinearScale.legacyToScene(BBCGammaTransfer.bbc04.decodeDataToLegacy(value))
                case .bbc05: try LinearScale.legacyToScene(BBCGammaTransfer.bbc05.decodeDataToLegacy(value))
                case .bbc06: try LinearScale.legacyToScene(BBCGammaTransfer.bbc06.decodeDataToLegacy(value))
                case .bbcWHP283400: try LinearScale.legacyToScene(BBCWHP283Transfer.percent400.decodeDataToLegacy(value))
                case .bbcWHP283800: try LinearScale.legacyToScene(BBCWHP283Transfer.percent800.decodeDataToLegacy(value))
                case .ituProposal400: try LinearScale.legacyToScene(ITUProposalTransfer.percent400.decodeDataToLegacy(value))
                case .ituProposal800: try LinearScale.legacyToScene(ITUProposalTransfer.percent800.decodeDataToLegacy(value))
                case .parameterizedGamma:
                    try decodeParameterizedGamma(value)
                case .gamma15, .gamma16, .gamma17, .gamma18, .gamma19, .gamma20,
                     .gamma21, .gamma22, .gamma23, .gamma24, .gamma25, .gamma26:
                    try LinearScale.legacyToScene(
                        ConventionalGammaTransfer.decodeDataToLegacy(value, transfer: settings.inputTransfer))
                }
            }
            return try RGB64(decode(input.r), decode(input.g), decode(input.b))
        }
        let workSpace: ColorSpaceID = workingSpace
        try step(3, to: .sceneReflectance, space: independentChannels ? settings.inputSpace : workSpace) {
            independentChannels ? $0 : try inputToWork.applying(to: $0)
        }
        try step(4, to: .sceneReflectance, space: independentChannels ? settings.inputSpace : workSpace) { input in
            try RGB64(input.r * exposureGain, input.g * exposureGain, input.b * exposureGain)
        }
        if let kernel=falseColourKernel {
            try step(5,to:.sceneReflectance,space:.sonySGamut3Cine) { input in
                falseColourBand=try kernel.classifyScene(input)
                return input
            }
        }
        if let kernel = ascCDLKernel {
            try step(8, to: .sceneReflectance, space: independentChannels ? settings.inputSpace : .sonySGamut3Cine) {
                try kernel.evaluateScene($0, applySaturation: !independentChannels)
            }
        }
        if let kernel = multitoneKernel {
            try step(9, to: .sceneReflectance, space: .sonySGamut3Cine) {
                try kernel.evaluateScene($0)
            }
        }
        try step(10, to: .sceneReflectance, space: settings.outputSpace) {
            if let kernel=highlightGamutKernel {return try kernel.evaluateScene($0)}
            return independentChannels ? $0 : try workToOutput.applying(to: $0)
        }
        if let kernel = sdrSaturationKernel {
            try step(11, to: .sceneReflectance, space: settings.outputSpace) {
                try kernel.evaluateScene($0)
            }
        }
        if let kernel=gamutLimiterKernel {
            try step(12,to:.sceneReflectance,space:settings.outputSpace) { input in
                if kernel.settings.mode == .linear {return try kernel.evaluateLinearScene(input)}
                secondaryScene=try kernel.secondaryScene(input)
                return input
            }
        }
        if let kernel = hlgOOTFKernel {
            // Synthetic trace id 130 is the explicit display-domain OOTF
            // substage. It runs immediately before stage 13's HLG OETF;
            // ids 06/07 remain reserved for the unresolved WB/PSST stages.
            try step(130, to: .displayLuminance, space: settings.outputSpace) { input in
                try kernel.sceneRGBToDisplay(input, side: .output)
            }
        }
        try step(13, to: settings.outputTransfer == .linearScene ? .sceneReflectance : .encodedData, space: settings.outputSpace) { input in
            func encode(_ value:Double)throws->Double {
                let scene = hlgOOTFKernel?.scale == .nits ? value * 0.001 : value
                return try outputEncoder.encodeScene(scene,knee:kneeKernel)
            }
            return try RGB64(encode(input.r), encode(input.g), encode(input.b))
        }
        if let kernel=blackHighlightKernel {
            try step(14,to:settings.outputTransfer == .linearScene ? .sceneReflectance : .encodedData,
                     space:settings.outputSpace) { try kernel.evaluate($0) }
        }
        if let kernel=blackGammaKernel {
            try step(15, to: settings.outputTransfer == .linearScene ? .sceneReflectance : .encodedData,
                     space:settings.outputSpace) { try kernel.evaluate($0) }
        }
        func display(_ input:RGB64,independent:Bool = false)throws->RGB64 {
            guard let kernel=displayKernel else{return input}
            let legal=try RGB64((input.r-outputEncoder.legalOffset)/outputEncoder.legalScale,
                (input.g-outputEncoder.legalOffset)/outputEncoder.legalScale,(input.b-outputEncoder.legalOffset)/outputEncoder.legalScale)
            let mapped=try kernel.evaluateLegal(legal,independentChannels:independent)
            return try RGB64(mapped.r*outputEncoder.legalScale+outputEncoder.legalOffset,
                mapped.g*outputEncoder.legalScale+outputEncoder.legalOffset,mapped.b*outputEncoder.legalScale+outputEncoder.legalOffset)
        }
        if let kernel=displayKernel {
            let displayUnit:SignalUnit = outputEncoder.legalScale != 1 || outputEncoder.legalOffset != 0 ? .encodedData :
                kernel.settings.outputCurve == .sceneReflectance ? .sceneReflectance : kernel.settings.outputCurve == .sceneIRE ? .legacyLinearIRE : .encodedLegal
            try step(16,to:displayUnit,space:finalSpace){try display($0,independent:independentChannels)}
        }
        if let kernel=gamutLimiterKernel,kernel.settings.mode == .postGamma {
            try step(17,to:unit,space:finalSpace) { input in
                let secondary:RGB64?
                if let scene=secondaryScene {
                    var displayScene = scene
                    if let ootf = hlgOOTFKernel {
                        displayScene = try ootf.sceneRGBToDisplay(scene, side: .output)
                    }
                    if hlgOOTFKernel?.scale == .nits {
                        displayScene = try RGB64(displayScene.r * 0.001,
                                                displayScene.g * 0.001,
                                                displayScene.b * 0.001)
                    }
                    var encoded=try RGB64(outputEncoder.encodeScene(displayScene.r,knee:kneeKernel),
                        outputEncoder.encodeScene(displayScene.g,knee:kneeKernel),outputEncoder.encodeScene(displayScene.b,knee:kneeKernel))
                    if let levels=blackHighlightKernel {encoded=try levels.evaluate(encoded)}
                    if let gamma=blackGammaKernel {encoded=try gamma.evaluate(encoded)}
                    encoded=try display(encoded)
                    secondary=try RGB64((encoded.r-outputEncoder.legalOffset)/outputEncoder.legalScale,
                        (encoded.g-outputEncoder.legalOffset)/outputEncoder.legalScale,(encoded.b-outputEncoder.legalOffset)/outputEncoder.legalScale)
                }else{secondary=nil}
                let legal=try RGB64((input.r-outputEncoder.legalOffset)/outputEncoder.legalScale,
                    (input.g-outputEncoder.legalOffset)/outputEncoder.legalScale,(input.b-outputEncoder.legalOffset)/outputEncoder.legalScale)
                let limited=try kernel.evaluateEncodedLegal(legal,secondary:secondary)
                return try RGB64(limited.r*outputEncoder.legalScale+outputEncoder.legalOffset,
                    limited.g*outputEncoder.legalScale+outputEncoder.legalOffset,limited.b*outputEncoder.legalScale+outputEncoder.legalOffset)
            }
        }
        if let kernel=falseColourKernel {
            try step(18,to:outputEncoder.legalScale != 1 || outputEncoder.legalOffset != 0 ? .encodedData : .diagnosticPaletteMixed,space:nil) { input in
                // Unmarked bands must preserve the original Double carrier.
                if [.belowGreen,.belowPink,.belowOrange,.unmarked].contains(falseColourBand){return input}
                let legal=try RGB64((input.r-outputEncoder.legalOffset)/outputEncoder.legalScale,
                    (input.g-outputEncoder.legalOffset)/outputEncoder.legalScale,(input.b-outputEncoder.legalOffset)/outputEncoder.legalScale)
                let marked=try kernel.overlayLegal(legal,band:falseColourBand)
                return try RGB64(marked.r*outputEncoder.legalScale+outputEncoder.legalOffset,
                    marked.g*outputEncoder.legalScale+outputEncoder.legalOffset,marked.b*outputEncoder.legalScale+outputEncoder.legalOffset)
            }
            displayGamut=nil
        }
        try step(19, to: settings.outputRange == .video ? .encodedVideo : finalOutputKernel != nil ? .encodedData : unit, space: falseColourKernel != nil ? nil : finalSpace) { input in
            if let kernel=finalOutputKernel {
                let legal=try RGB64((input.r-outputEncoder.legalOffset)/outputEncoder.legalScale,
                    (input.g-outputEncoder.legalOffset)/outputEncoder.legalScale,(input.b-outputEncoder.legalOffset)/outputEncoder.legalScale)
                return try kernel.evaluateLegal(legal)
            }
            if settings.outputRange == .data { return input }
            return try RGB64(
                videoRange.dataToVideo(input.r),
                videoRange.dataToVideo(input.g),
                videoRange.dataToVideo(input.b)
            )
        }
        return StageTrace(output: current, stages: stages)
    }
}
