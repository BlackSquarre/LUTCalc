import Foundation

public enum FinalOutputAlgorithm:String,Codable,Sendable {case lutcalcCodeLimitsV1 = "lutcalc.final-output-code-limits.v1"}
public enum FinalOutputClipMode:String,Codable,CaseIterable,Sendable {case none,both,blackOnly,whiteOnly}
public enum FinalOutputError:Error,Equatable,Sendable {case hdrLimitUnavailable}
public struct FinalOutputSettings:Equatable,Codable,Sendable {
    public let algorithm:FinalOutputAlgorithm
    public let enabled:Bool
    public let mode:FinalOutputClipMode
    public let clipLegal:Bool
    /// Format constraints are expressed in the old normalized 10-bit code units.
    public let minimumCode10:Double,maximumCode10:Double
    public let forceBlackLegal:Bool
    public init(enabled:Bool = true,mode:FinalOutputClipMode = .blackOnly,clipLegal:Bool = true,
                minimumCode10:Double = 0,maximumCode10:Double = 67025937,forceBlackLegal:Bool = false,
                algorithm:FinalOutputAlgorithm = .lutcalcCodeLimitsV1)throws {
        guard minimumCode10.isFinite,maximumCode10.isFinite else{throw NumericError.nonFinite}
        self.enabled=enabled;self.mode=mode;self.clipLegal=clipLegal;self.minimumCode10=minimumCode10
        self.maximumCode10=maximumCode10;self.forceBlackLegal=forceBlackLegal;self.algorithm=algorithm
    }
    private enum CodingKeys:String,CodingKey {case algorithm,enabled,mode,clipLegal,minimumCode10,maximumCode10,forceBlackLegal}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),mode:c.decode(FinalOutputClipMode.self,forKey:.mode),
            clipLegal:c.decode(Bool.self,forKey:.clipLegal),minimumCode10:c.decode(Double.self,forKey:.minimumCode10),
            maximumCode10:c.decode(Double.self,forKey:.maximumCode10),forceBlackLegal:c.decode(Bool.self,forKey:.forceBlackLegal),
            algorithm:c.decode(FinalOutputAlgorithm.self,forKey:.algorithm))
    }
}
public struct LegacyFinalOutput:Sendable {
    public let settings:FinalOutputSettings
    public let outputRange:SignalNormalization
    public let minimum:Double,maximum:Double
    /// HDR limits must come from a prepared HDR/OOTF model, never guessed from
    /// a generic PQ/HLG alias. Tests can pass explicit independent context.
    public init(settings:FinalOutputSettings,outputRange:SignalNormalization,
                hdrOutputActive:Bool = false,hdrMaximumLegal:Double? = nil,displayConversionActive:Bool = false)throws {
        self.settings=settings;self.outputRange=outputRange
        let legal=outputRange == .video
        var lo=legal ? (settings.forceBlackLegal ? 0 : (settings.minimumCode10-64)/876) :
            (settings.forceBlackLegal ? 64.0/1023 : settings.minimumCode10/1023)
        var hi=legal ? (settings.maximumCode10-64)/876 : settings.maximumCode10/1023
        let black=settings.mode == .both || settings.mode == .blackOnly
        let white=settings.mode == .both || settings.mode == .whiteOnly
        if settings.mode != .none {
            if legal || !settings.clipLegal {
                if black && lo<0{lo=0};if white && hi>1{hi=1}
            }else{
                if black && lo<64.0/1023{lo=64.0/1023};if white && hi>959.0/1023{hi=959.0/1023}
            }
        }
        if hdrOutputActive && !displayConversionActive {
            guard let mx=hdrMaximumLegal else{throw FinalOutputError.hdrLimitUnavailable}
            guard mx.isFinite else{throw NumericError.nonFinite}
            let cap=legal ? mx : mx*0.85630498533724+0.06256109481916
            guard cap.isFinite else{throw NumericError.nonFinite}
            if cap<hi{hi=cap}
        }
        guard lo.isFinite,hi.isFinite else{throw NumericError.nonFinite}
        // Preserve reversed limits and HDR ceilings below the black floor:
        // min(ceiling,max(floor,x)) returns the ceiling in that case.
        minimum=lo;maximum=hi
    }
    public func evaluateLegal(_ value:Double)throws->Double {
        guard value.isFinite else{throw NumericError.nonFinite}
        let mapped=outputRange == .video ? value : (value*876+64)/1023
        guard mapped.isFinite else{throw NumericError.nonFinite}
        return min(maximum,max(minimum,mapped))
    }
    public func evaluateLegal(_ value:RGB64)throws->RGB64 {
        try RGB64(evaluateLegal(value.r),evaluateLegal(value.g),evaluateLegal(value.b))
    }
}
