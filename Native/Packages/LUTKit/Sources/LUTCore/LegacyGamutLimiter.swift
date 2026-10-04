import Foundation

public enum GamutLimiterAlgorithm:String,Codable,Sendable {
    case lutcalcChromaSpanV1 = "lutcalc.gamut-limiter-chroma-span.v1"
}
public enum GamutLimiterMode:String,Codable,Sendable {case linear,postGamma}

/// Linear stops select 2^stops in legacy linear (reference white=1).
/// Post level selects a Legal IRE span; it is not a maximum component value.
public struct GamutLimiterSettings:Equatable,Codable,Sendable {
    public let algorithm:GamutLimiterAlgorithm
    public let enabled:Bool
    public let mode:GamutLimiterMode
    public let linearStops:Double
    public let postLevel:Double
    public let secondarySpace:ColorSpaceID?
    public let protectBoth:Bool
    public init(enabled:Bool = true,mode:GamutLimiterMode = .postGamma,
                linearStops:Double = 0,postLevel:Double = 1,secondarySpace:ColorSpaceID? = nil,
                protectBoth:Bool = true,algorithm:GamutLimiterAlgorithm = .lutcalcChromaSpanV1) throws {
        guard linearStops.isFinite,(-6...6).contains(linearStops),postLevel.isFinite,(0.01...1.09).contains(postLevel)
        else{throw NumericError.invalidDomain}
        self.algorithm=algorithm;self.enabled=enabled;self.mode=mode;self.linearStops=linearStops
        self.postLevel=postLevel;self.secondarySpace=secondarySpace;self.protectBoth=protectBoth
    }
    private enum CodingKeys:String,CodingKey{case algorithm,enabled,mode,linearStops,postLevel,secondarySpace,protectBoth}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),mode:c.decode(GamutLimiterMode.self,forKey:.mode),
            linearStops:c.decode(Double.self,forKey:.linearStops),postLevel:c.decode(Double.self,forKey:.postLevel),
            secondarySpace:c.decodeIfPresent(ColorSpaceID.self,forKey:.secondarySpace),protectBoth:c.decode(Bool.self,forKey:.protectBoth),
            algorithm:c.decode(GamutLimiterAlgorithm.self,forKey:.algorithm))
    }
}

/// Immutable stage-12 preparation and stage-17 chroma span limiter.
public struct LegacyGamutLimiter:Sendable {
    public let settings:GamutLimiterSettings
    public let luma:RGB64
    public let hasSecondary:Bool
    private let intoWork:Matrix3x3
    private let workToSecondary:Matrix3x3

    public init(settings:GamutLimiterSettings,outputSpace:ColorSpaceID,adaptation:ChromaticAdaptation)throws {
        self.settings=settings
        let output=outputSpace.primaries,m=try output.rgbToXYZ().rowMajor
        luma=try RGB64(m[3],m[4],m[5])
        hasSecondary=settings.secondarySpace.map{$0 != outputSpace} ?? false
        if hasSecondary,let secondary=settings.secondarySpace {
            // Retain the old two matrix operations, including their rounding.
            intoWork=try ColorPrimaries.conversion(from:output,to:.sonySGamut3Cine,adaptation:adaptation)
            workToSecondary=try ColorPrimaries.conversion(from:.sonySGamut3Cine,to:secondary.primaries,adaptation:adaptation)
        }else{intoWork = .identity;workToSecondary = .identity}
    }
    public func secondaryLegacy(_ primary:RGB64)throws->RGB64? {
        guard settings.enabled,hasSecondary else{return nil}
        return try workToSecondary.applying(to:intoWork.applying(to:primary))
    }
    public func secondaryScene(_ primary:RGB64)throws->RGB64? {
        guard settings.enabled,hasSecondary else{return nil}
        let legacy=try RGB64(LinearScale.sceneToLegacy(primary.r),LinearScale.sceneToLegacy(primary.g),LinearScale.sceneToLegacy(primary.b))
        guard let secondary=try secondaryLegacy(legacy) else{return nil}
        return try RGB64(LinearScale.legacyToScene(secondary.r),LinearScale.legacyToScene(secondary.g),LinearScale.legacyToScene(secondary.b))
    }
    private func clampZero(_ p:RGB64)throws->RGB64 {try RGB64(max(0,p.r),max(0,p.g),max(0,p.b))}
    private func limit(_ primary:RGB64,secondary:RGB64?,level:Double)throws->RGB64 {
        let spread=max(primary.r,primary.g,primary.b)-min(primary.r,primary.g,primary.b)
        var selected=spread
        if hasSecondary {
            guard let secondary else{throw NumericError.invalidDomain}
            let alternate=max(secondary.r,secondary.g,secondary.b)-min(secondary.r,secondary.g,secondary.b)
            selected=settings.protectBoth ? max(spread,alternate) : alternate
        }
        let ratio=selected/level
        guard ratio.isFinite else{throw NumericError.nonFinite}
        guard ratio>1 else{return primary}
        let y=luma.r*primary.r+luma.g*primary.g+luma.b*primary.b
        guard y.isFinite else{throw NumericError.nonFinite}
        return try RGB64(y+(primary.r-y)/ratio,y+(primary.g-y)/ratio,y+(primary.b-y)/ratio)
    }
    public func evaluateLinearLegacy(_ primary:RGB64)throws->RGB64 {
        guard settings.enabled else{return primary}
        let clamped=try clampZero(primary)
        // Linear mode derives the alternate from the clamped primary.
        return try limit(clamped,secondary:secondaryLegacy(clamped),level:pow(2,settings.linearStops))
    }
    public func evaluateLinearScene(_ primary:RGB64)throws->RGB64 {
        guard settings.enabled else{return primary}
        let legacy=try RGB64(LinearScale.sceneToLegacy(primary.r),LinearScale.sceneToLegacy(primary.g),LinearScale.sceneToLegacy(primary.b))
        let result=try evaluateLinearLegacy(legacy)
        return try RGB64(LinearScale.legacyToScene(result.r),LinearScale.legacyToScene(result.g),LinearScale.legacyToScene(result.b))
    }
    public func evaluateEncodedLegal(_ primary:RGB64,secondary:RGB64?)throws->RGB64 {
        guard settings.enabled else{return primary}
        // Post mode only clamps the primary. The alternate is the stage-12
        // snapshot after the same output adjustments, still allowed negative.
        return try limit(clampZero(primary),secondary:secondary,level:settings.postLevel)
    }
}
