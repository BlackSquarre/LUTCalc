import Foundation

public enum HighlightGamutAlgorithm:String,Codable,Sendable {
    case lutcalcOutputBlendV1 = "lutcalc.highlight-gamut-output-blend.v1"
}
public enum HighlightGamutTransition:String,Codable,Sendable {
    case linearReflectance
    case logarithmicStops
}
public struct HighlightGamutSettings:Equatable,Codable,Sendable {
    public let algorithm:HighlightGamutAlgorithm
    public let enabled:Bool
    public let highlightSpace:ColorSpaceID
    public let transition:HighlightGamutTransition
    public let lowStops:Double
    public let highStops:Double

    public init(enabled:Bool = true,highlightSpace:ColorSpaceID,
                transition:HighlightGamutTransition = .linearReflectance,
                lowStops:Double = 0,highStops:Double = 2.3219,
                algorithm:HighlightGamutAlgorithm = .lutcalcOutputBlendV1) throws {
        let low=pow(2,lowStops)/5,high=pow(2,highStops)/5
        guard lowStops.isFinite,highStops.isFinite,lowStops<highStops,
              low.isFinite,high.isFinite,low>0,high>low,(high-low).isFinite
        else{throw NumericError.invalidDomain}
        self.algorithm=algorithm;self.enabled=enabled;self.highlightSpace=highlightSpace
        self.transition=transition;self.lowStops=lowStops;self.highStops=highStops
    }
    private enum CodingKeys:String,CodingKey{case algorithm,enabled,highlightSpace,transition,lowStops,highStops}
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),highlightSpace:c.decode(ColorSpaceID.self,forKey:.highlightSpace),
            transition:c.decode(HighlightGamutTransition.self,forKey:.transition),lowStops:c.decode(Double.self,forKey:.lowStops),
            highStops:c.decode(Double.self,forKey:.highStops),algorithm:c.decode(HighlightGamutAlgorithm.self,forKey:.algorithm))
    }
}

/// Legacy stage 10 replaces the ordinary work-to-output conversion. Its Y
/// deliberately uses working luma dotted with the converted base RGB, not
/// the base space's physical luminance. Alternate coordinates are blended
/// numerically without a second gamut conversion. Both choices are versioned.
public struct LegacyHighlightGamut:Sendable {
    public let settings:HighlightGamutSettings
    public let workingLuma:RGB64
    public let lowLegacy:Double
    public let highLegacy:Double
    private let baseMatrix:Matrix3x3
    private let highlightMatrix:Matrix3x3

    public init(settings:HighlightGamutSettings,basePrimaries:ColorPrimaries,
                adaptation:ChromaticAdaptation) throws {
        self.settings=settings
        let work=ColorPrimaries.sonySGamut3Cine,m=try work.rgbToXYZ().rowMajor
        workingLuma=try RGB64(m[3],m[4],m[5])
        baseMatrix=try ColorPrimaries.conversion(from:work,to:basePrimaries,adaptation:adaptation)
        highlightMatrix=try ColorPrimaries.conversion(from:work,to:settings.highlightSpace.primaries,adaptation:adaptation)
        lowLegacy=pow(2,settings.lowStops)/5;highLegacy=pow(2,settings.highStops)/5
    }
    public func evaluateLegacy(_ input:RGB64)throws->RGB64 {
        let base=try baseMatrix.applying(to:input)
        guard settings.enabled else{return base}
        let high=try highlightMatrix.applying(to:input)
        let y=workingLuma.r*base.r+workingLuma.g*base.g+workingLuma.b*base.b
        guard y.isFinite else{throw NumericError.nonFinite}
        if y>=highLegacy{return high}
        guard y>lowLegacy else{return base}
        let ratio:Double
        switch settings.transition {
        case .linearReflectance:ratio=(highLegacy-y)/(highLegacy-lowLegacy)
        case .logarithmicStops:
            ratio=(settings.highStops-log(y*5)/log(2))/(settings.highStops-settings.lowStops)
        }
        guard ratio.isFinite else{throw NumericError.nonFinite}
        return try RGB64(base.r*ratio+high.r*(1-ratio),base.g*ratio+high.g*(1-ratio),base.b*ratio+high.b*(1-ratio))
    }
    public func evaluateScene(_ input:RGB64)throws->RGB64 {
        let legacy=try RGB64(LinearScale.sceneToLegacy(input.r),LinearScale.sceneToLegacy(input.g),LinearScale.sceneToLegacy(input.b))
        let result=try evaluateLegacy(legacy)
        return try RGB64(LinearScale.legacyToScene(result.r),LinearScale.legacyToScene(result.g),LinearScale.legacyToScene(result.b))
    }
}
