import Foundation

public enum BlackHighlightAlgorithm: String, Codable, Sendable {
    case lutcalcLegalAffineV1 = "lutcalc.black-highlight-legal-affine.v1"
}

/// Map values use Legal IRE; the reference is scene reflectance.
public struct BlackHighlightSettings: Equatable, Codable, Sendable {
    public let algorithm: BlackHighlightAlgorithm
    public let enabled: Bool
    public let doBlack: Bool
    public let doHigh: Bool
    public let blackLevel: Double?
    public let blackLock: Bool
    public let highReferenceScene: Double
    public let highMap: Double?
    public let highLock: Bool

    public init(enabled: Bool = true, doBlack: Bool = false, doHigh: Bool = false,
                blackLevel: Double? = nil, blackLock: Bool = false,
                highReferenceScene: Double = 0.9, highMap: Double? = nil, highLock: Bool = false,
                algorithm: BlackHighlightAlgorithm = .lutcalcLegalAffineV1) throws {
        guard highReferenceScene.isFinite, highReferenceScene>0,
              blackLevel.map({$0.isFinite && $0 > -0.073}) ?? true,
              highMap.map({$0.isFinite && $0 > -0.073}) ?? true else { throw NumericError.invalidDomain }
        self.algorithm=algorithm
        self.enabled=enabled
        self.doBlack=doBlack
        self.doHigh=doHigh
        self.blackLevel=blackLevel
        self.blackLock=blackLock
        self.highReferenceScene=highReferenceScene
        self.highMap=highMap
        self.highLock=highLock
    }

    private init(copy:Self, blackLevel:Double?, highMap:Double?) {
        algorithm=copy.algorithm;enabled=copy.enabled;doBlack=copy.doBlack;doHigh=copy.doHigh
        self.blackLevel=blackLevel;blackLock=copy.blackLock;highReferenceScene=copy.highReferenceScene
        self.highMap=highMap;highLock=copy.highLock
    }

    public func rebasedForChanges(outputChanged:Bool = false, cdlChanged:Bool = false,
                                 hdrChanged:Bool = false, referenceChanged:Bool = false) -> Self {
        let reset=outputChanged || cdlChanged || hdrChanged
        return Self(copy:self,blackLevel:reset && !blackLock ? nil : blackLevel,
                    highMap:(reset || referenceChanged) && !highLock ? nil : highMap)
    }

    public func withHighReferenceScene(_ value:Double) throws -> Self {
        let next=try Self(enabled:enabled,doBlack:doBlack,doHigh:doHigh,blackLevel:blackLevel,
            blackLock:blackLock,highReferenceScene:value,highMap:highMap,highLock:highLock,algorithm:algorithm)
        return next.rebasedForChanges(referenceChanged:value != highReferenceScene)
    }

    private enum CodingKeys:String,CodingKey {
        case algorithm,enabled,doBlack,doHigh,blackLevel,blackLock,highReferenceScene,highMap,highLock
    }
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),doBlack:c.decode(Bool.self,forKey:.doBlack),
            doHigh:c.decode(Bool.self,forKey:.doHigh),blackLevel:c.decodeIfPresent(Double.self,forKey:.blackLevel),
            blackLock:c.decode(Bool.self,forKey:.blackLock),highReferenceScene:c.decode(Double.self,forKey:.highReferenceScene),
            highMap:c.decodeIfPresent(Double.self,forKey:.highMap),highLock:c.decode(Bool.self,forKey:.highLock),
            algorithm:c.decode(BlackHighlightAlgorithm.self,forKey:.algorithm))
    }
}

/// Defaults and samples share one encoding unit. Explicit map values are
/// converted from Legal IRE before the affine coefficients are prepared.
public struct LegacyBlackHighlight: Sendable {
    public let settings: BlackHighlightSettings
    public let blackMap: Double
    public let highMap: Double
    public let slope: Double
    public let intercept: Double
    private let active: Bool

    public init(settings:BlackHighlightSettings,blackDefault:Double,highDefault:Double,
                legalToNativeScale:Double = 1,legalToNativeOffset:Double = 0) throws {
        guard blackDefault.isFinite,highDefault.isFinite,legalToNativeScale.isFinite,
              legalToNativeScale>0,legalToNativeOffset.isFinite else { throw NumericError.nonFinite }
        self.settings=settings
        let isActive=settings.enabled && (settings.doBlack || settings.doHigh)
        active=isActive
        func selected(_ value:Double?,locked:Bool,adjust:Bool,defaultValue:Double)throws->Double {
            guard isActive,adjust,let value else{return defaultValue}
            let legalDefault=(defaultValue-legalToNativeOffset)/legalToNativeScale
            guard legalDefault.isFinite else{throw NumericError.nonFinite}
            if !locked && abs(value-legalDefault)<=0.0001{return defaultValue}
            let converted=value*legalToNativeScale+legalToNativeOffset
            guard converted.isFinite else{throw NumericError.nonFinite}
            return converted
        }
        let b=try selected(settings.blackLevel,locked:settings.blackLock,adjust:settings.doBlack,defaultValue:blackDefault)
        let h=try selected(settings.highMap,locked:settings.highLock,adjust:settings.doHigh,defaultValue:highDefault)
        blackMap=b;highMap=h
        if !isActive {slope=1;intercept=0;return}
        let span=highDefault-blackDefault
        guard span.isFinite,span != 0 else{throw NumericError.invalidDomain}
        let a=(h-b)/span,z=b-blackDefault*a
        guard a.isFinite,z.isFinite else{throw NumericError.nonFinite}
        slope=a;intercept=z
    }

    public func evaluate(_ value:Double) throws -> Double {
        guard value.isFinite else{throw NumericError.nonFinite}
        guard active else{return value}
        let output=value*slope+intercept
        guard output.isFinite else{throw NumericError.nonFinite}
        return output
    }
    public func evaluate(_ value:RGB64) throws -> RGB64 {
        try RGB64(evaluate(value.r),evaluate(value.g),evaluate(value.b))
    }
}

