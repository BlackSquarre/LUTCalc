import Foundation

/// The SDR buffer algorithms offered by the old Display Colourspace Converter.
/// The four HDR/OOTF variants have separate parameter contracts and are not aliases.
public enum DisplayCurve:String,Codable,CaseIterable,Sendable {
    case rec709,rec2020,srgb,dci26,sceneIRE,sceneReflectance,cieLStar,bbc04,bbc05,bbc06,proPhoto
    case gamma15,gamma16,gamma17,gamma18,gamma19,gamma20,gamma21,gamma22,gamma23,gamma24,gamma25,gamma26
    private var bbc:BBCGammaTransfer? {switch self{case .bbc04:.bbc04;case .bbc05:.bbc05;case .bbc06:.bbc06;default:nil}}
    private var powerParameters:ParameterizedGammaTransfer? {
        let exponent:Double
        switch self {
        case .rec709:return try! ParameterizedGammaTransfer(exponent:1/0.45,linearSlope:4.5,offset:0.099,linearCut:0.018,encodedCut:0.081)
        case .rec2020:return try! ParameterizedGammaTransfer(exponent:1/0.45,linearSlope:4.5,offset:0.0993,linearCut:0.0181,encodedCut:0.08145)
        case .srgb:return try! ParameterizedGammaTransfer(exponent:2.4,linearSlope:12.92,offset:0.055,linearCut:0.0031308,encodedCut:0.04015966)
        case .cieLStar:return try! ParameterizedGammaTransfer(exponent:3,linearSlope:24389.0/2700,offset:0.16,linearCut:216.0/24389,encodedCut:216.0/2700)
        case .proPhoto:
            let cut=pow(16,1.8 / -0.8)
            return try! ParameterizedGammaTransfer(exponent:1.8,linearSlope:16,offset:0,linearCut:cut,encodedCut:pow(cut,1/1.8))
        case .gamma15:exponent=1.5
        case .gamma16:exponent=1.6
        case .gamma17:exponent=1.7
        case .gamma18:exponent=1.8
        case .gamma19:exponent=1.9
        case .gamma20:exponent=2
        case .gamma21:exponent=2.1
        case .gamma22:exponent=2.2
        case .gamma23:exponent=2.3
        case .gamma24:exponent=2.4
        case .gamma25:exponent=2.5
        case .gamma26,.dci26:exponent=2.6
        default:return nil
        }
        return try! ParameterizedGammaTransfer(exponent:exponent,linearSlope:1,offset:0,linearCut:1e-7,encodedCut:1e-7)
    }
    public func decodeLegal(_ value:Double)throws->Double {
        guard value.isFinite else{throw NumericError.nonFinite}
        let result:Double
        if let p=powerParameters {result=try p.decodeLegalToLegacy(value)}
        else if let bbc {
            // Buffer linFromL uses strict >, unlike the old scalar inverse.
            result=value>bbc.encodedCut ? (1+bbc.offset)*pow(value,1/bbc.exponent)-bbc.offset : value/bbc.slope
        }else{result=self == .sceneReflectance ? value/0.9 : value}
        guard result.isFinite else{throw NumericError.nonFinite};return result
    }
    public func encodeLegal(_ value:Double)throws->Double {
        guard value.isFinite else{throw NumericError.nonFinite}
        let result:Double
        if let p=powerParameters {result=try p.encodeLegacyToLegal(value)}
        else if let bbc {
            result=value>bbc.linearCut ? pow((value+bbc.offset)/(1+bbc.offset),bbc.exponent) : value*bbc.slope
        }else{result=self == .sceneReflectance ? value*0.9 : value}
        guard result.isFinite else{throw NumericError.nonFinite};return result
    }
}

public enum DisplayGamut:String,Codable,CaseIterable,Sendable {
    case rec709,rec2020,srgb,p3DCI,p3D60,p3D65,proPhoto
    var primaries:ColorPrimaries {
        switch self {
        case .rec709,.srgb:return .srgb
        case .rec2020:return .rec2020
        case .proPhoto:return .proPhoto
        case .p3DCI,.p3D60,.p3D65:
            let white=try! Chromaticity(x:self == .p3DCI ? 0.314 : self == .p3D60 ? 0.32168 : 0.3127,
                y:self == .p3DCI ? 0.351 : self == .p3D60 ? 0.33767 : 0.329)
            return try! ColorPrimaries(red:Chromaticity(x:0.68,y:0.32),green:Chromaticity(x:0.265,y:0.69),blue:Chromaticity(x:0.15,y:0.06),white:white)
        }
    }
    var colorSpaceID:ColorSpaceID? {switch self{case .rec709,.srgb:.srgb;case .rec2020:.rec2020;case .p3D65:.displayP3;case .proPhoto:.proPhoto;default:nil}}
}
public enum DisplayConversionAlgorithm:String,Codable,Sendable {
    case lutcalcSDRV1 = "lutcalc.display-sdr-decode-matrix-encode.v1"
}
public struct DisplayConversionSettings:Equatable,Codable,Sendable {
    public let algorithm:DisplayConversionAlgorithm
    public let enabled:Bool
    public let baseCurve:DisplayCurve
    public let outputCurve:DisplayCurve
    public let baseGamut:DisplayGamut
    public let outputGamut:DisplayGamut
    public init(enabled:Bool = true,baseCurve:DisplayCurve = .rec709,outputCurve:DisplayCurve = .rec709,
                baseGamut:DisplayGamut = .rec709,outputGamut:DisplayGamut = .rec709,
                algorithm:DisplayConversionAlgorithm = .lutcalcSDRV1) {
        self.algorithm=algorithm;self.enabled=enabled;self.baseCurve=baseCurve;self.outputCurve=outputCurve
        self.baseGamut=baseGamut;self.outputGamut=outputGamut
    }
}
public struct LegacyDisplayConversion:Sendable {
    public let settings:DisplayConversionSettings
    private let matrix:Matrix3x3
    public init(settings:DisplayConversionSettings)throws {
        self.settings=settings
        if settings.baseGamut == settings.outputGamut {matrix = .identity}
        else {
            // The legacy display matrices use fixed CAT02, independently of
            // the colourspace pipeline's selected CAT. Derive, never copy them.
            let into=try ColorPrimaries.conversion(from:settings.baseGamut.primaries,to:.sonySGamut3Cine,adaptation:.cieCAT02)
            let out=try ColorPrimaries.conversion(from:.sonySGamut3Cine,to:settings.outputGamut.primaries,adaptation:.cieCAT02)
            matrix=try out.multiplied(by:into)
        }
    }
    public func evaluateLegal(_ value:RGB64,independentChannels:Bool = false)throws->RGB64 {
        guard settings.enabled else{return value}
        var p=try RGB64(settings.baseCurve.decodeLegal(value.r),settings.baseCurve.decodeLegal(value.g),settings.baseCurve.decodeLegal(value.b))
        if !independentChannels,settings.baseGamut != settings.outputGamut {p=try matrix.applying(to:p)}
        return try RGB64(settings.outputCurve.encodeLegal(p.r),settings.outputCurve.encodeLegal(p.g),settings.outputCurve.encodeLegal(p.b))
    }
}
