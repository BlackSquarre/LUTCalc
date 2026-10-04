import Foundation

public enum CameraISOBehavior:Int,Codable,Sendable {
    case cineEI = 0, curveParameters = 1, bakedGain = 2
}
public struct CameraProfile:Equatable,Sendable {
    public let id:String
    public let make:String
    public let model:String
    public let baseISO:Int
    public let behavior:CameraISOBehavior
    public let legacyGamma:String
    public let legacyGamut:String
    public let blackStops:Double
    public let clipStops:Double
    public let source:String
    public var reportedNativeISO:Int? { model == "Generic" ? nil : baseISO }
}
public enum CameraInputPolicy:String,Codable,Sendable {
    case explicitCurrentInput = "camera.explicit-current-input.v1"
    case legacyAvailableDefaults = "camera.legacy-available-defaults.v1"
    case publishedAvailableDefaults = "camera.published-available-defaults.v1"
}
public enum CameraStopSource:String,Codable,Sendable {
    case recordedISO = "recorded-iso.v1"
    case manualStop = "manual-stop.v1"
    case batchOverride = "batch-override.v1"
}
public enum CameraExposureError:Error,Equatable,Sendable {
    case unknownProfile(String),invalidISO,invalidStops,stateMismatch,unknownAlgorithm
    case unsupportedDefaults(String)
}

enum CameraExposureMath {
    // Equivalent to Number.toFixed(4) parsed as a Double: round the exact
    // binary64 magnitude, with ties to the larger magnitude. Multiplying the
    // Double by 10000 first would introduce a second rounding at ties.
    static func legacyFourDecimalStop(_ x:Double)->Double {
        precondition(x.isFinite && abs(x)<64)
        if x == 0 {return x}
        let bits=abs(x).bitPattern,exponent=Int((bits>>52)&0x7ff)
        let significand=(bits & 0x000f_ffff_ffff_ffff) | (exponent == 0 ? 0 : 0x0010_0000_0000_0000)
        let shift=exponent == 0 ? 1074 : 1075-exponent
        let product=significand.multipliedFullWidth(by:10000)
        var quotient:UInt64=0,roundBit:UInt64=0
        if shift<128 {
            if shift>=64 {
                quotient=product.high >> (shift-64)
                roundBit=shift == 64 ? product.low >> 63 : (product.high >> (shift-65)) & 1
            }else {
                quotient=(product.high << (64-shift)) | (product.low >> shift)
                roundBit=(product.low >> (shift-1)) & 1
            }
        }
        let rounded=Double(quotient+roundBit)/10000
        return x.sign == .minus ? -rounded : rounded
    }
    static func stop(recordedISO:Int,baseISO:Int)->Double {
        legacyFourDecimalStop(log(Double(recordedISO)/Double(baseISO))/log(2))
    }
    static func shiftedISO(baseISO:Int,stop:Double)throws->Int {
        let value=(Double(baseISO)*pow(2,stop)).rounded(.toNearestOrAwayFromZero)
        guard value.isFinite,value>=1,value<=9007199254740991 else {throw CameraExposureError.invalidISO}
        return Int(value)
    }
}

public struct CameraExposureSettings:Equatable,Codable,Sendable {
    public static let currentAlgorithm="lutcalc.camera-exposure-state.v1"
    public let algorithm:String
    public let profileID:String
    public let recordedISO:Int
    public let stopCorrection:Double
    public let source:CameraStopSource
    public let inputPolicy:CameraInputPolicy

    private init(profileID:String,recordedISO:Int,stopCorrection:Double,source:CameraStopSource,inputPolicy:CameraInputPolicy) {
        algorithm=Self.currentAlgorithm;self.profileID=profileID;self.recordedISO=recordedISO
        self.stopCorrection=stopCorrection;self.source=source;self.inputPolicy=inputPolicy
    }
    public var profile:CameraProfile { CameraCatalog.profile(id:profileID)! }
    public var gain:Double {get throws {
        let value=pow(2,stopCorrection)
        guard stopCorrection.isFinite,value.isFinite,value>0 else {throw CameraExposureError.invalidStops}
        return value
    }}
    private func auxiliaryScene(stops:Double)throws->Double {
        let value=0.18*pow(2,stops+stopCorrection)
        guard value.isFinite,value>=0 else {throw CameraExposureError.invalidStops}
        return value
    }
    public var blackScene:Double {get throws {try auxiliaryScene(stops:profile.blackStops)}}
    public var clipScene:Double {get throws {try auxiliaryScene(stops:profile.clipStops)}}
    public func validate()throws {
        guard algorithm == Self.currentAlgorithm else {throw CameraExposureError.unknownAlgorithm}
        guard let p=CameraCatalog.profile(id:profileID) else {throw CameraExposureError.unknownProfile(profileID)}
        guard (1...9007199254740991).contains(recordedISO) else {throw CameraExposureError.invalidISO}
        _=try gain;_=try blackScene;_=try clipScene
        if p.behavior == .cineEI {
            switch source {
            case .recordedISO:
                guard stopCorrection.bitPattern == CameraExposureMath.stop(recordedISO:recordedISO,baseISO:p.baseISO).bitPattern else {throw CameraExposureError.stateMismatch}
            case .manualStop:
                guard recordedISO == (try CameraExposureMath.shiftedISO(baseISO:p.baseISO,stop:stopCorrection)) else {throw CameraExposureError.stateMismatch}
            case .batchOverride:break
            }
        }
    }
    public static func selecting(profileID:String,inputPolicy:CameraInputPolicy)throws->Self {
        guard let p=CameraCatalog.profile(id:profileID) else {throw CameraExposureError.unknownProfile(profileID)}
        return try fromRecordedISO(profileID:profileID,recordedISO:p.baseISO,inputPolicy:inputPolicy)
    }
    public static func fromRecordedISO(profileID:String,recordedISO:Int,previousManualStops:Double=0,inputPolicy:CameraInputPolicy)throws->Self {
        guard let p=CameraCatalog.profile(id:profileID) else {throw CameraExposureError.unknownProfile(profileID)}
        guard (1...9007199254740991).contains(recordedISO),previousManualStops.isFinite else {throw CameraExposureError.invalidISO}
        let stops=p.behavior == .cineEI ? CameraExposureMath.stop(recordedISO:recordedISO,baseISO:p.baseISO) : previousManualStops
        let state=Self(profileID:profileID,recordedISO:recordedISO,stopCorrection:stops,source:.recordedISO,inputPolicy:inputPolicy)
        try state.validate();return state
    }
    public func changingRecordedISO(_ iso:Int)throws->Self {
        try Self.fromRecordedISO(profileID:profileID,recordedISO:iso,previousManualStops:stopCorrection,inputPolicy:inputPolicy)
    }
    public func changingStopCorrection(_ stops:Double)throws->Self {
        guard stops.isFinite else {throw CameraExposureError.invalidStops}
        let iso=profile.behavior == .cineEI ? try CameraExposureMath.shiftedISO(baseISO:profile.baseISO,stop:stops) : recordedISO
        let state=Self(profileID:profileID,recordedISO:iso,stopCorrection:stops,source:.manualStop,inputPolicy:inputPolicy)
        try state.validate();return state
    }
    public func overridingExposureStops(_ stops:Double)->Self {
        // Batch exposure replaces the source stop without changing ISO or
        // curve parameters. Validation happens when the new plan is prepared.
        Self(profileID:profileID,recordedISO:recordedISO,stopCorrection:stops,source:.batchOverride,inputPolicy:inputPolicy)
    }
    public func applyingExposure(to settings:TransformSettings)throws->TransformSettings {
        try validate()
        var result=settings.withExposureStops(stopCorrection).withCameraExposure(self)
        if let p=settings.inputLogC {
            result=result.withInputLogC(try ARRILogCSceneSettings(algorithm:p.algorithm,exposureIndex:recordedISO))
        }
        if let p=settings.outputLogC {
            result=result.withOutputLogC(try ARRILogCSceneSettings(algorithm:p.algorithm,exposureIndex:recordedISO))
        }
        return result
    }
    private enum CodingKeys:String,CodingKey {case algorithm,profileID,recordedISO,stopCorrection,source,inputPolicy}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        guard try c.decode(String.self,forKey:.algorithm) == Self.currentAlgorithm else {throw CameraExposureError.unknownAlgorithm}
        self.init(profileID:try c.decode(String.self,forKey:.profileID),recordedISO:try c.decode(Int.self,forKey:.recordedISO),
            stopCorrection:try c.decode(Double.self,forKey:.stopCorrection),source:try c.decode(CameraStopSource.self,forKey:.source),
            inputPolicy:try c.decode(CameraInputPolicy.self,forKey:.inputPolicy))
        try validate()
    }
}
