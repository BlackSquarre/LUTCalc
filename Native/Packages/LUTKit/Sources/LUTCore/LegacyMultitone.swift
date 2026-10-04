import Foundation

public enum MultitoneAlgorithm: String, Codable, Sendable {
    case lutcalcWorkingV1 = "lutcalc.multitone-working.v1"
}

public struct MultitoneTone: Equatable, Codable, Sendable {
    public let stop: Double
    public let hue: UInt8
    public let saturation: UInt8
    public init(stop: Double, hue: UInt8, saturation: UInt8) throws {
        guard stop.isFinite else { throw NumericError.nonFinite }
        self.stop=stop;self.hue=hue;self.saturation=saturation
    }
    private enum CodingKeys: String, CodingKey { case stop, hue, saturation }
    public init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(stop:c.decode(Double.self,forKey:.stop),hue:c.decode(UInt8.self,forKey:.hue),
                      saturation:c.decode(UInt8.self,forKey:.saturation))
    }
}

public struct MultitoneSettings: Equatable, Codable, Sendable {
    public let algorithm: MultitoneAlgorithm
    public let enabled: Bool
    /// User-defined saturation at scene stops -8...+8, not an internal LUT.
    public let saturationByStop: [Double]
    public let tones: [MultitoneTone]
    public init(enabled: Bool = true, saturationByStop: [Double] = Array(repeating:1,count:17),
                tones: [MultitoneTone] = [], algorithm: MultitoneAlgorithm = .lutcalcWorkingV1) throws {
        guard saturationByStop.count==17,
              saturationByStop.allSatisfy({$0.isFinite && (0...2).contains($0)}) else { throw NumericError.invalidDomain }
        for i in tones.indices.dropFirst() {
            let interval=tones[i].stop-tones[i-1].stop
            guard interval.isFinite, interval>0 else { throw NumericError.invalidDomain }
        }
        self.algorithm=algorithm;self.enabled=enabled;self.saturationByStop=saturationByStop;self.tones=tones
    }
    private enum CodingKeys: String, CodingKey { case algorithm, enabled, saturationByStop, tones }
    public init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(enabled:c.decode(Bool.self,forKey:.enabled),
                      saturationByStop:c.decode([Double].self,forKey:.saturationByStop),
                      tones:c.decode([MultitoneTone].self,forKey:.tones),
                      algorithm:c.decode(MultitoneAlgorithm.self,forKey:.algorithm))
    }
}

/// Retains the old tone preparation in output primaries and mixing in work RGB.
/// Each user tone is computed directly; no 256x256 colour square is generated.
public struct LegacyMultitone: Sendable {
    public let settings: MultitoneSettings
    public let luma: RGB64
    public let preparedTones: [RGB64]
    public init(settings: MultitoneSettings, outputPrimaries: ColorPrimaries,
                adaptation: ChromaticAdaptation = .cieCAT02) throws {
        self.settings=settings
        let y=try ColorPrimaries.sonySGamut3Cine.rgbToXYZ().rowMajor
        luma=try RGB64(y[3],y[4],y[5])
        let into=try ColorPrimaries.conversion(from:.srgb,to:.sonySGamut3Cine,adaptation:adaptation)
        let out=try ColorPrimaries.conversion(from:.sonySGamut3Cine,to:outputPrimaries,adaptation:adaptation)
        preparedTones=try settings.tones.map {
            try out.applying(to:into.applying(to:Self.pickerRGB(hue:$0.hue,saturation:$0.saturation)))
        }
    }
    public static func pickerRGB(hue: UInt8, saturation: UInt8) throws -> RGB64 {
        // Direct retained HSL equation, L=0.5. Byte-valued user parameters stay exact.
        let h=6*Double(hue)/255, s=Double(saturation)/255
        let x=s*(1-abs(h.truncatingRemainder(dividingBy:2)-1)), m=0.5-0.5*s
        let rgb: (Double,Double,Double)
        switch h {
        case ..<1: rgb=(s,x,0)
        case ..<2: rgb=(x,s,0)
        case ..<3: rgb=(0,s,x)
        case ..<4: rgb=(0,x,s)
        case ..<5: rgb=(x,0,s)
        default: rgb=(s,0,x)
        }
        return try RGB64(rgb.0+m,rgb.1+m,rgb.2+m)
    }
    private func tone(at stop: Double) throws -> RGB64? {
        guard let first=preparedTones.first, let last=preparedTones.last else { return nil }
        if stop<=settings.tones[0].stop {return first}
        if stop>=settings.tones[settings.tones.count-1].stop {return last}
        var lower=0, upper=settings.tones.count-1
        while upper-lower>1 {
            let middle=(lower+upper)/2
            if settings.tones[middle].stop>stop {upper=middle} else {lower=middle}
        }
        let r=(stop-settings.tones[lower].stop)/(settings.tones[upper].stop-settings.tones[lower].stop)
        let a=preparedTones[lower],b=preparedTones[upper]
        return try RGB64((1-r)*a.r+r*b.r,(1-r)*a.g+r*b.g,(1-r)*a.b+r*b.b)
    }
    public func evaluateLegacy(_ input: RGB64) throws -> RGB64 {
        guard settings.enabled else { return input }
        let y=luma.r*input.r+luma.g*input.g+luma.b*input.b
        guard y.isFinite else { throw NumericError.nonFinite }
        var mono=try RGB64(y,y,y)
        let sat: Double
        if y<=0 { sat=settings.saturationByStop[0] }
        else {
            let index=log(y/0.2)/log(2)+8
            if index<=0 {sat=settings.saturationByStop[0]}
            else if index>=16 {sat=settings.saturationByStop[16]}
            else {
                let b=Int(floor(index)),r=index-Double(b)
                sat=(1-r)*settings.saturationByStop[b]+r*settings.saturationByStop[b+1]
            }
            if sat<1, let color=try tone(at:index-8) {
                let y2=luma.r*color.r+luma.g*color.g+luma.b*color.b
                guard y2.isFinite else { throw NumericError.nonFinite }
                if y2>0 {
                    let gain=y/y2
                    mono=try RGB64(color.r*gain,color.g*gain,color.b*gain)
                }
            }
        }
        return try RGB64(mono.r+sat*(input.r-mono.r),mono.g+sat*(input.g-mono.g),mono.b+sat*(input.b-mono.b))
    }
    public func evaluateScene(_ input: RGB64) throws -> RGB64 {
        guard settings.enabled else {return input}
        let legacy=try RGB64(LinearScale.sceneToLegacy(input.r),LinearScale.sceneToLegacy(input.g),LinearScale.sceneToLegacy(input.b))
        let result=try evaluateLegacy(legacy)
        return try RGB64(LinearScale.legacyToScene(result.r),LinearScale.legacyToScene(result.g),LinearScale.legacyToScene(result.b))
    }
}
