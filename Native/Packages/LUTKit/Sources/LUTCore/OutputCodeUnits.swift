import Foundation

/// Keep the previous incomplete native metadata only for reproducible old projects.
/// New requests use the complete classification of the actual encoder result.
public enum OutputCodeUnitPolicy:String,Codable,Sendable {
    case partialV1 = "native.output-code-units.partial.v1"
    case completeV2 = "native.output-code-units.complete.v2"
}

extension TransferID {
    var usesRoundedLegacyDataWrapper:Bool {
        switch self {
        case .nullLUTCalcLegacy,.cieLStar,.proPhoto,.bbc04,.bbc05,.bbc06,.bbcWHP283400,.bbcWHP283800,
             .gamma15,.gamma16,.gamma17,.gamma18,.gamma19,.gamma20,.gamma21,.gamma22,
             .gamma23,.gamma24,.gamma25,.gamma26,.ituProposal400,.ituProposal800:return true
        default:return false
        }
    }
    // Classify the actual return value, rather than the transfer method name.
    var hasNormalizedDataEncoding:Bool {
        if usesRoundedLegacyDataWrapper{return true}
        switch self {
        case .djiDLog2,.sonySLog3,.sonySLog3LUTCalcLegacy,.sonySLog2,.sonySLog2LUTCalcLegacy,.sonySLog,.sonySLogLUTCalcLegacy,.nikonNLog,.nikonNLogLUTCalcLegacy,.cineon,.cineonLUTCalcLegacy,.redLogFilm,.redLogFilmLUTCalcLegacy,.redLog3G10LUTCalcLegacy,.arriLogC4,.arriLogCSUP2Scene,.arriLogCSUP3Scene,.panasonicVLog,
             .blackmagicFilmGen5,.blackmagicFilmGen5LUTCalcLegacy,
             .blackmagicFilmLUTCalcLegacy,.blackmagicFilm4kLUTCalcLegacy,.blackmagicFilm46kLUTCalcLegacy,
             .bolexLogLUTCalcLegacy,.panalogLUTCalcLegacy,.djiX5LogLUTCalcLegacy,.goProProtuneLUTCalcLegacy,.djiX3DLogLUTCalcLegacy,
             .daVinciIntermediateLUTCalcLegacy,
             .canonCLog2,.canonCLog2LUTCalcLegacy,
             .canonCLog3,.canonCLogLUTCalcLegacy,.blackmagicPocketFilmLUTCalcLegacy,.rec2020TenBit,.rec2020TwelveBit,
             .fujifilmFLog2,.fujifilmFLog2LUTCalcLegacy,.insta360ILog,.xiaomiMiLog,.leicaLLog,
             .fujifilmFLogLUTCalcLegacy,.kineLog3,.appleLogOriginal,.appleLog2,.acesProxy10,.acesProxy12:return true
        default:return false
        }
    }
    func outputLegalScale(policy:OutputCodeUnitPolicy)->Double {
        if usesRoundedLegacyDataWrapper{return policy == .completeV2 ? 0.85630498533724 : 1}
        return hasNormalizedDataEncoding ? 876.0/1023 : 1
    }
    func outputLegalOffset(policy:OutputCodeUnitPolicy)->Double {
        if usesRoundedLegacyDataWrapper{return policy == .completeV2 ? 0.06256109481916 : 0}
        return hasNormalizedDataEncoding ? 64.0/1023 : 0
    }
}
