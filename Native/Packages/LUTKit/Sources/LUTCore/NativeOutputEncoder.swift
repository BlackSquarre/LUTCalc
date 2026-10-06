import Foundation

/// One immutable output encoder shared by stage 13 and adjustment anchors.
struct NativeOutputEncoder:Sendable {
    let transfer:TransferID
    let codeUnits:OutputCodeUnitPolicy
    let logC: ARRILogCCompact?
    let parameterized:ParameterizedGammaTransfer?
    init(settings:TransformSettings)throws {
        try settings.validateParameterizedTransfers()
        logC=try settings.outputLogC?.makeTransfer()
        transfer=settings.outputTransfer
        codeUnits=settings.outputCodeUnits
        parameterized=try settings.outputGamma?.makeTransfer()
    }
    var legalScale:Double{transfer.outputLegalScale(policy:codeUnits)}
    var legalOffset:Double{transfer.outputLegalOffset(policy:codeUnits)}
    private func encodeLogC(_ x: Double) throws -> Double {
        guard let logC else { throw NumericError.invalidDomain }
        return try logC.encode(x)
    }
    private func encodeParameterized(_ x:Double)throws->Double {
        guard let parameterized else{throw NumericError.invalidDomain}
        return try parameterized.encodeLegacyToLegal(LinearScale.sceneToLegacy(x))
    }
    func encodeLegacyToLegal(_ x:Double)throws->Double {
        (try encodeScene(LinearScale.legacyToScene(x))-legalOffset)/legalScale
    }
    func encodeScene(_ x:Double,knee:LegacyKnee?)throws->Double {
        let normal=try encodeScene(x)
        guard let knee,let mapped=try knee.mappedLegal(LinearScale.sceneToLegacy(x)) else{return normal}
        let result=mapped*legalScale+legalOffset
        guard result.isFinite else{throw NumericError.nonFinite};return result
    }
    func encodeScene(_ value:Double)throws->Double {
        return switch transfer {
        case .linearScene: value
        case .nullLUTCalcLegacy:
            try NullTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .djiDLog2: try DLog2.encodeSceneToData(value)
        case .srgbW3CExtended: try SRGBTransfer.encode(value, variant: .w3cExtended)
        case .srgbLUTCalcLegacy: try SRGBTransfer.encode(
            LinearScale.sceneToLegacy(value), variant: .lutcalcLegacy)
        case .rec709LUTCalcLegacy: try Rec709Transfer.encodeLegacy(
            LinearScale.sceneToLegacy(value))
        case .rec2020TenBit: try Rec2020TenBitTransfer.encodeSceneToData(value)
        case .rec2020Continuous: try Rec2020ContinuousTransfer.encodeSceneToData(value)
        case .smpte240M: try SMPTE240MTransfer.encodeSceneToData(value)
        case .rec2020TwelveBit: try Rec2020TwelveBitTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .cineon: try CineonTransfer.encodeSceneToData(value)
        case .cineonLUTCalcLegacy: try CineonTransfer.encodeLegacyToData(try LinearScale.sceneToLegacy(value))
        case .redLogFilm: try REDLogFilmTransfer.encodeSceneToData(value)
        case .redLogFilmLUTCalcLegacy: try REDLogFilmTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .redLog3G10LUTCalcLegacy:
            try REDLog3G10Transfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .sonySLog3: try SLog3Transfer.encodeSonySceneToData(value)
        case .sonySLog3LUTCalcLegacy: try SLog3Transfer.encodeLegacyToData(
            LinearScale.sceneToLegacy(value))
        case .sonySLog2: try SonyLegacyLogTransfer.encodeSLog2ToData(value)
        case .sonySLog2LUTCalcLegacy: try SonyLegacyLogTransfer.encodeSLog2LegacyToData(LinearScale.sceneToLegacy(value))
        case .sonySLog: try SonyLegacyLogTransfer.encodeSLogToData(value)
        case .sonySLogLUTCalcLegacy: try SonyLegacyLogTransfer.encodeSLogLegacyToData(LinearScale.sceneToLegacy(value))
        case .nikonNLog: try NikonNLogTransfer.encodeSceneToData(value)
        case .nikonNLogLUTCalcLegacy: try NikonNLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .arriLogCSUP2Scene, .arriLogCSUP3Scene: try encodeLogC(value)
        case .arriLogC4: try LogC4Transfer.encodeSceneToData(value)
        case .blackmagicFilmGen5: try BMDGen5Transfer.encodeSceneToData(value)
        case .blackmagicFilmGen5LUTCalcLegacy: try BMDGen5Transfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .canonCLog2: try CanonCLog2Transfer.encodeSceneToData(value)
        case .canonCLog2LUTCalcLegacy: try CanonCLog2Transfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .canonCLog3: try CanonCLog3Transfer.encodeSceneToData(value)
        case .canonCLogLUTCalcLegacy: try CanonCLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .blackmagicPocketFilmLUTCalcLegacy:
            try BMDPocketFilmTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .blackmagicFilmLUTCalcLegacy:
            try BMDLegacyFilmTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .film)
        case .blackmagicFilm4kLUTCalcLegacy:
            try BMDLegacyFilmTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .film4k)
        case .blackmagicFilm46kLUTCalcLegacy:
            try BMDLegacyFilmTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .film46k)
        case .bolexLogLUTCalcLegacy:
            try LegacyRegisteredLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .bolex)
        case .panalogLUTCalcLegacy:
            try LegacyRegisteredLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .panalog)
        case .djiX5LogLUTCalcLegacy:
            try LegacyRegisteredLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .djiX5)
        case .goProProtuneLUTCalcLegacy:
            try LegacyRegisteredLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value), variant: .protune)
        case .djiX3DLogLUTCalcLegacy:
            try DJIX3DLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .daVinciIntermediateLUTCalcLegacy:
            try DaVinciIntermediateTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .panasonicVLog: try VLogTransfer.encodeSceneToData(value)
        case .fujifilmFLog2: try FLog2Transfer.encodeSceneToData(value)
        case .fujifilmFLog2LUTCalcLegacy: try FLog2Transfer.encodeLegacyToData(
            LinearScale.sceneToLegacy(value))
        case .fujifilmFLogLUTCalcLegacy:
            try FLogTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .acesCCT: try ACESCCTTransfer.encodeLinearAP1ToCCT(value)
        case .acesCC: try ACESCCTransfer.encodeLinearAP1ToCC(value)
        case .acesProxy10: try ACESProxyTransfer.ten.encodeLinearAP1ToData(value)
        case .acesProxy12: try ACESProxyTransfer.twelve.encodeLinearAP1ToData(value)
        case .insta360ILog: try ILogTransfer.encodeSceneToData(value)
        case .xiaomiMiLog: try MiLogTransfer.encodeSceneToData(value)
        case .leicaLLog: try LeicaLLogTransfer.encodeSceneToData(value)
        case .kineLog3: try KineLog3Transfer.encodeSceneToData(value)
        case .gpLog2: try GPLog2Transfer.encodeSceneToData(value)
        case .appleLogOriginal, .appleLog2: try AppleLogTransfer.encodeSceneToData(value)
        case .rec2100HLG: try HLGTransfer.encodeSceneToData(value)
        case .rec2100PQ: try PQTransfer.encodeNormalizedLuminanceToData(value)
        // The output transfer maps normalized luminance back to the
        // display signal domain.
        case .bt1886: try BT1886Transfer.decodeLuminanceToDisplay(value)
        case .cieLStar: try CIELStarTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .proPhoto: try ProPhotoTransfer.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .bbc04: try BBCGammaTransfer.bbc04.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .bbc05: try BBCGammaTransfer.bbc05.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .bbc06: try BBCGammaTransfer.bbc06.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .bbcWHP283400: try BBCWHP283Transfer.percent400.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .bbcWHP283800: try BBCWHP283Transfer.percent800.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .ituProposal400: try ITUProposalTransfer.percent400.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .ituProposal800: try ITUProposalTransfer.percent800.encodeLegacyToData(LinearScale.sceneToLegacy(value))
        case .parameterizedGamma:
            try encodeParameterized(value)
        case .gamma15, .gamma16, .gamma17, .gamma18, .gamma19, .gamma20,
             .gamma21, .gamma22, .gamma23, .gamma24, .gamma25, .gamma26:
            try ConventionalGammaTransfer.encodeLegacyToData(
                LinearScale.sceneToLegacy(value), transfer: transfer)
        }
    }
}
