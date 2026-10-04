import Foundation

public enum FalseColourAlgorithm:String,Codable,Sendable {
    case nativeThresholdsV1 = "lutcalc.false-colour-native-thresholds.v1"
}
/// Export is explicit. A future preview overlay must not enable LUT export.
public enum FalseColourUsage:String,Codable,Sendable {case exportLUT}
public enum FalseColourBand:Int,Codable,Sendable {
    case purple=0,blue=1,belowGreen=2,green=3,belowPink=4,pink=5,belowOrange=6,orange=7,unmarked=8,yellow=9,red=10
}
public struct FalseColourSettings:Equatable,Codable,Sendable {
    public let algorithm:FalseColourAlgorithm
    public let usage:FalseColourUsage
    public let enabled:Bool
    public let doPurple:Bool,doBlue:Bool,doGreen:Bool,doPink:Bool,doOrange:Bool,doYellow:Bool,doRed:Bool
    public let blueStopsBelowGray:Double?,yellowStopsBelowClip:Double?,redStopsAboveGray:Double?
    public var isActive:Bool {enabled && (doPurple || doBlue || doGreen || doPink || doOrange || doYellow || doRed)}
    /// nil preserves worker fallback defaults, distinct from UI defaults.
    public init(enabled:Bool = true,doPurple:Bool = true,doBlue:Bool = true,doGreen:Bool = true,
                doPink:Bool = true,doOrange:Bool = false,doYellow:Bool = true,doRed:Bool = true,
                blueStopsBelowGray:Double? = 6.1,yellowStopsBelowClip:Double? = 0.5,redStopsAboveGray:Double? = 6,
                usage:FalseColourUsage = .exportLUT,algorithm:FalseColourAlgorithm = .nativeThresholdsV1)throws {
        for x in [blueStopsBelowGray,yellowStopsBelowClip,redStopsAboveGray].compactMap({$0}) {
            guard x.isFinite else{throw NumericError.nonFinite}
        }
        guard blueStopsBelowGray.map({$0>=1}) ?? true,
              yellowStopsBelowClip.map({$0>=0.0001 && $0<=3}) ?? true,
              redStopsAboveGray.map({$0>=3.5}) ?? true else{throw NumericError.invalidDomain}
        self.enabled=enabled;self.doPurple=doPurple;self.doBlue=doBlue;self.doGreen=doGreen
        self.doPink=doPink;self.doOrange=doOrange;self.doYellow=doYellow;self.doRed=doRed
        self.blueStopsBelowGray=blueStopsBelowGray;self.yellowStopsBelowClip=yellowStopsBelowClip;self.redStopsAboveGray=redStopsAboveGray
        self.usage=usage;self.algorithm=algorithm
    }
    private enum CodingKeys:String,CodingKey {
        case algorithm,usage,enabled,doPurple,doBlue,doGreen,doPink,doOrange,doYellow,doRed
        case blueStopsBelowGray,yellowStopsBelowClip,redStopsAboveGray
    }
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),doPurple:c.decode(Bool.self,forKey:.doPurple),
            doBlue:c.decode(Bool.self,forKey:.doBlue),doGreen:c.decode(Bool.self,forKey:.doGreen),doPink:c.decode(Bool.self,forKey:.doPink),
            doOrange:c.decode(Bool.self,forKey:.doOrange),doYellow:c.decode(Bool.self,forKey:.doYellow),doRed:c.decode(Bool.self,forKey:.doRed),
            blueStopsBelowGray:c.decodeIfPresent(Double.self,forKey:.blueStopsBelowGray),yellowStopsBelowClip:c.decodeIfPresent(Double.self,forKey:.yellowStopsBelowClip),
            redStopsAboveGray:c.decodeIfPresent(Double.self,forKey:.redStopsAboveGray),usage:c.decode(FalseColourUsage.self,forKey:.usage),
            algorithm:c.decode(FalseColourAlgorithm.self,forKey:.algorithm))
    }
}

public struct LegacyFalseColour:Sendable {
    public let settings:FalseColourSettings
    public let thresholds:[Double]
    public let luma:RGB64
    public init(settings:FalseColourSettings)throws {
        self.settings=settings
        // Derive the old cofactor operation order from the public primaries.
        // Discontinuous band classification requires these rounded coefficients.
        let p=ColorPrimaries.sonySGamut3Cine
        let m=[p.red.x,p.green.x,p.blue.x,p.red.y,p.green.y,p.blue.y,
               1-p.red.x-p.red.y,1-p.green.x-p.green.y,1-p.blue.x-p.blue.y]
        let det=m[0]*(m[4]*m[8]-m[5]*m[7])-m[1]*(m[3]*m[8]-m[5]*m[6])+m[2]*(m[3]*m[7]-m[4]*m[6])
        let inv=[(m[4]*m[8]-m[5]*m[7])/det,(m[2]*m[7]-m[1]*m[8])/det,(m[1]*m[5]-m[2]*m[4])/det,
                 (m[5]*m[6]-m[3]*m[8])/det,(m[0]*m[8]-m[2]*m[6])/det,(m[2]*m[3]-m[0]*m[5])/det,
                 (m[3]*m[7]-m[4]*m[6])/det,(m[1]*m[6]-m[0]*m[7])/det,(m[0]*m[4]-m[1]*m[3])/det]
        let w=[p.white.x/p.white.y,1,(1-p.white.x-p.white.y)/p.white.y]
        luma=try RGB64((inv[0]*w[0]+inv[1]*w[1]+inv[2]*w[2])*m[3],
            (inv[3]*w[0]+inv[4]*w[1]+inv[5]*w[2])*m[4],(inv[6]*w[0]+inv[7]*w[1]+inv[8]*w[2])*m[5])
        var t=[Double](repeating:-10,count:10)
        if settings.isActive {
            if settings.doPurple{t[0]=pow(2,-8)*0.2}
            if settings.doBlue{t[1]=pow(2,-(settings.blueStopsBelowGray ?? 6.1))*0.2;t[0]=pow(2,-10)*0.2}
            // These are the legacy band's rounded definition constants,
            // not sampled transfer values or vendor LUT data.
            if settings.doGreen{t[2]=0.174110113;t[3]=0.229739671}
            if settings.doPink{t[4]=0.354307008;t[5]=0.451585762}
            if settings.doOrange{t[6]=0.885767519;t[7]=1.128964405}
            if settings.doYellow{t[8]=pow(2,(settings.redStopsAboveGray ?? 5.95)-(settings.yellowStopsBelowClip ?? 0.26))*0.2;t[9]=pow(2,5.95)*0.2}
            if settings.doRed{t[9]=pow(2,settings.redStopsAboveGray ?? 5.95)*0.2}
        }
        guard t.allSatisfy(\.isFinite) else{throw NumericError.nonFinite};thresholds=t
    }
    public func classifyLumaLegacy(_ y:Double)throws->FalseColourBand? {
        guard y.isFinite else{throw NumericError.nonFinite}
        guard settings.isActive else{return nil}
        var band=0
        for i in 0..<10 where thresholds[i] != -10 {
            if y<=thresholds[i]{band=i;break}
        }
        if band==0 && settings.doRed && y>thresholds[9]{band=10}
        else if (band==0 && y>thresholds[0]) || (band==0 && !settings.doPurple && y<0.1) || (band==9 && !settings.doYellow){band=8}
        return FalseColourBand(rawValue:band)!
    }
    public func classifyLegacy(_ input:RGB64)throws->FalseColourBand? {
        try classifyLumaLegacy(luma.r*input.r+luma.g*input.g+luma.b*input.b)
    }
    public func classifyScene(_ input:RGB64)throws->FalseColourBand? {
        try classifyLegacy(RGB64(LinearScale.sceneToLegacy(input.r),LinearScale.sceneToLegacy(input.g),LinearScale.sceneToLegacy(input.b)))
    }
    public func overlayLegal(_ original:RGB64,band:FalseColourBand?)throws->RGB64 {
        guard settings.isActive,let band else{return original}
        return switch band {
        case .purple:try RGB64(0.75,0,0.75)
        case .blue:try RGB64(0,0,0.75)
        case .green:try RGB64(0,0.7,0)
        case .pink:try RGB64(0.75,0.35,0.35)
        case .orange:try RGB64(0.9,0.45,0)
        case .yellow:try RGB64(0.7,0.7,0)
        case .red:try RGB64(0.75,0,0)
        default:original
        }
    }
}
