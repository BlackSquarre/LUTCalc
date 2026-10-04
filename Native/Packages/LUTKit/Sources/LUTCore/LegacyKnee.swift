import Foundation

/// Compatibility with the legacy two-Hermite output Knee. It does not
/// guarantee global monotonicity; the legacy second-segment test was omitted.
public enum KneeAlgorithm:String,Codable,Sendable {
    case lutcalcOutputHermiteV1 = "lutcalc.knee-output-hermite.v1"
}

public struct KneeSettings:Equatable,Codable,Sendable {
    public let algorithm:KneeAlgorithm
    public let enabled:Bool
    public let startStops:Double
    public let clipStops:Double
    public let clipSlope:Double
    public let smoothness:Double
    public let legal:Bool

    public init(enabled:Bool = true,startStops:Double = 0.05,clipStops:Double = 6,
                clipSlope:Double = 0.25,smoothness:Double = 1,legal:Bool = true,
                algorithm:KneeAlgorithm = .lutcalcOutputHermiteV1) throws {
        guard startStops.isFinite,(-5...8).contains(startStops),clipStops.isFinite,
              (0.05...8).contains(clipStops),startStops<clipStops,clipSlope.isFinite,
              (0...2.5).contains(clipSlope),smoothness.isFinite,(0...1).contains(smoothness)
        else{throw NumericError.invalidDomain}
        self.algorithm=algorithm;self.enabled=enabled;self.startStops=startStops;self.clipStops=clipStops
        self.clipSlope=clipSlope;self.smoothness=smoothness;self.legal=legal
    }
    private enum CodingKeys:String,CodingKey{case algorithm,enabled,startStops,clipStops,clipSlope,smoothness,legal}
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),startStops:c.decode(Double.self,forKey:.startStops),
            clipStops:c.decode(Double.self,forKey:.clipStops),clipSlope:c.decode(Double.self,forKey:.clipSlope),
            smoothness:c.decode(Double.self,forKey:.smoothness),legal:c.decode(Bool.self,forKey:.legal),
            algorithm:c.decode(KneeAlgorithm.self,forKey:.algorithm))
    }
}

/// Preparation and evaluation use legacy linear (scene / 0.9) and Legal IRE.
/// No colour coupling or sampled transfer tables occur in this kernel.
public struct LegacyKnee:Sendable {
    public let settings:KneeSettings
    public let maximumStartStops:Double?
    public let startStops:Double
    public let clipStops:Double
    public let thresholdLegacy:Double
    public let spanStops:Double
    public let p0:Double,p1:Double,p2:Double,d0:Double,d1:Double,d2:Double,split:Double,tailSlope:Double
    public let active:Bool

    public init(settings:KneeSettings,cdl:ASCCDLSettings? = nil,
                encodeLegacyToLegal:(Double)throws->Double) throws {
        self.settings=settings
        guard settings.enabled else {
            maximumStartStops=nil;startStops=settings.startStops;clipStops=settings.clipStops
            thresholdLegacy=0;spanStops=clipStops-startStops;p0=0;p1=0;p2=0;d0=0;d1=0;d2=0
            split=0.5;tailSlope=0;active=false;return
        }
        func f(_ stop:Double)throws->Double {
            let encoded=try encodeLegacyToLegal(pow(2,stop)/5)
            guard encoded.isFinite else{throw NumericError.nonFinite};return encoded
        }
        var maximum:Double?,j=8.0
        while j>0 {
            if try f(j)<=0.95{maximum=j;break};j-=0.1
        }
        maximumStartStops=maximum
        let start=min(settings.startStops,maximum ?? 0)
        var clip=settings.clipStops
        if let cdl,cdl.enabled {
            let x=pow(2,clip)*0.2,kernel=try LegacyASCCDL(settings:cdl)
            let a=try kernel.evaluateLegacy(RGB64(x,x,x),applySaturation:false)
            let y=0.2126*a.r+0.7152*a.g+0.0722*a.b
            guard y.isFinite,y>0 else{throw NumericError.invalidDomain}
            clip=log(y/0.2)/log(2)
        }
        let range=clip-start
        guard range.isFinite,range != 0 else{throw NumericError.invalidDomain}
        startStops=start;clipStops=clip;thresholdLegacy=pow(2,start)*0.2;spanStops=range
        let q0=try f(start),q2=settings.legal ? 0.99 : 959.0/876-0.01
        var v0=try (f(start+0.001)-f(start-0.001))*range/0.002
        let slope=settings.clipSlope/100
        var v2=slope*range
        let a=2*q0+v0-2*q2+v2,b = -3*q0-2*v0+3*q2-v2
        var q1=Self.polynomial(a,b,v0,q0,0.5)
        var v1=(Self.polynomial(a,b,v0,0,0.501)-Self.polynomial(a,b,v0,0,0.499))/0.002
        v0/=2;v1/=2;v2/=2
        var s=0.5
        if v0>=0 {
            q1=min(q1,0.1*q0+0.9*q2);v1=max(v1,(q2-q1)/0.9)
            let a0=2*q0+v0-2*q1+v1,b0 = -3*q0-2*v0+3*q1-v1
            let disc=b0*b0-3*a0*v0
            if disc>=0 {
                let root=sqrt(disc),rp=(-b0+root)/(3*a0),rm=(-b0-root)/(3*a0)
                if (rp>0 && rp<1) || (rm>0 && rm<1) {
                    q1=0.1*q0+0.9*q2;v1=(q1-q0)*1.29/6.59;s=10.89*v1/(1.29*v0)
                }
            }
        }
        guard [q0,q1,q2,v0,v1,v2,s,slope,thresholdLegacy].allSatisfy(\.isFinite),s>0,s<1
        else{throw NumericError.invalidDomain}
        p0=q0;p1=q1;p2=q2;d0=v0;d1=v1;d2=v2;split=s;tailSlope=slope;active=v0>=0
    }

    private static func polynomial(_ a:Double,_ b:Double,_ c:Double,_ d:Double,_ x:Double)->Double {
        ((a*x+b)*x+c)*x+d
    }
    /// Nil means use the unmodified native encoder result (no unit roundtrip).
    public func mappedLegal(_ input:Double)throws->Double? {
        guard input.isFinite else{throw NumericError.nonFinite}
        guard active,input>=thresholdLegacy else{return nil}
        let stop=log(input/0.2)/log(2),output:Double
        if stop<clipStops {
            let s=(stop-startStops)/spanStops,pa:Double,pb:Double,da:Double,db:Double,t:Double
            if s<split {
                pa=p0;pb=p1;da=d0/(2*(1-split));db=d1/(2*(1-split));t=s/split
            }else{
                pa=p1;pb=p2;da=d1/(2*split);db=d2/(2*split);t=(s-split)/(1-split)
            }
            let a=2*pa+da-2*pb+db,b = -3*pa-2*da+3*pb-db
            output=Self.polynomial(a,b,da,pa,t)*settings.smoothness+(p0*(1-s)+p2*s)*(1-settings.smoothness)
        }else{output=p2+(stop-clipStops)*tailSlope}
        guard output.isFinite else{throw NumericError.nonFinite};return output
    }
    public func evaluateLegacy(_ input:Double,encodedLegal:Double)throws->Double {
        guard encodedLegal.isFinite else{throw NumericError.nonFinite}
        return try mappedLegal(input) ?? encodedLegal
    }
}
