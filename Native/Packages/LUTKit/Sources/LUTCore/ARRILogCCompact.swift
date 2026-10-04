import Foundation

/// Published compact equations use the listed decimal calibration coefficients.
/// Camera shoulders, sensor clipping, gamut and undocumented EIs are separate.
public struct ARRILogCCompact: Sendable {
    public enum Firmware: String, Codable, CaseIterable, Sendable { case sup2, sup3 }
    public enum LinearDomain: String, Codable, CaseIterable, Sendable { case sensorSignal, sceneExposure }
    public enum Failure: Error, Equatable, Sendable { case unsupportedExposureIndex(Int) }
    public struct Parameters: Sendable {
        public let cut: Double, a: Double, b: Double, c: Double, d: Double, e: Double, f: Double
        public var encodedCut: Double { e * cut + f }
    }
    public static let supportedExposureIndices = [160,200,250,320,400,500,640,800,1000,1280,1600]
    public let firmware: Firmware
    public let domain: LinearDomain
    public let exposureIndex: Int
    public let parameters: Parameters
    public var algorithm: String { firmware == .sup3 ? "arri.logc-sup3-compact-published.v1" : "arri.logc-sup2-compact-published.v1" }
    public static let sup3ReferenceURL = "https://www.arri.com/resource/blob/31918/66f56e6abb6e5b6553929edf9aa7483b/2017-03-alexa-logc-curve-in-vfx-data.pdf"
    public static let sup2Reference = "ARRI ALEXA Log C Curve Usage in VFX, 2012 appendix, archived research/colour/2026-10-02-logc3/arri-logc-vfx-2012-mirror.pdf"
    public init(firmware: Firmware, domain: LinearDomain, exposureIndex: Int) throws {
        self.firmware = firmware; self.domain = domain; self.exposureIndex = exposureIndex
        // Analytical formula coefficients from the cited appendix, not pixel samples.
        switch (firmware, domain, exposureIndex) {
        case (.sup3, .sensorSignal, 160): parameters = Parameters(cut: 0.004680, a: 40.0, b: -0.076072, c: 0.269036, d: 0.381991, e: 42.062665, f: -0.071569)
        case (.sup3, .sensorSignal, 200): parameters = Parameters(cut: 0.004597, a: 50.0, b: -0.118740, c: 0.266007, d: 0.382478, e: 51.986387, f: -0.110339)
        case (.sup3, .sensorSignal, 250): parameters = Parameters(cut: 0.004518, a: 62.5, b: -0.171260, c: 0.262978, d: 0.382966, e: 64.243053, f: -0.158224)
        case (.sup3, .sensorSignal, 320): parameters = Parameters(cut: 0.004436, a: 80.0, b: -0.243808, c: 0.259627, d: 0.383508, e: 81.183335, f: -0.224409)
        case (.sup3, .sensorSignal, 400): parameters = Parameters(cut: 0.004369, a: 100.0, b: -0.325820, c: 0.256598, d: 0.383999, e: 100.295280, f: -0.299079)
        case (.sup3, .sensorSignal, 500): parameters = Parameters(cut: 0.004309, a: 125.0, b: -0.427461, c: 0.253569, d: 0.384493, e: 123.889239, f: -0.391261)
        case (.sup3, .sensorSignal, 640): parameters = Parameters(cut: 0.004249, a: 160.0, b: -0.568709, c: 0.250219, d: 0.385040, e: 156.482680, f: -0.518605)
        case (.sup3, .sensorSignal, 800): parameters = Parameters(cut: 0.004201, a: 200.0, b: -0.729169, c: 0.247190, d: 0.385537, e: 193.235573, f: -0.662201)
        case (.sup3, .sensorSignal, 1000): parameters = Parameters(cut: 0.004160, a: 250.0, b: -0.928805, c: 0.244161, d: 0.386036, e: 238.584745, f: -0.839385)
        case (.sup3, .sensorSignal, 1280): parameters = Parameters(cut: 0.004120, a: 320.0, b: -1.207168, c: 0.240810, d: 0.386590, e: 301.197380, f: -1.084020)
        case (.sup3, .sensorSignal, 1600): parameters = Parameters(cut: 0.004088, a: 400.0, b: -1.524256, c: 0.237781, d: 0.387093, e: 371.761171, f: -1.359723)
        case (.sup3, .sceneExposure, 160): parameters = Parameters(cut: 0.005561, a: 5.555556, b: 0.080216, c: 0.269036, d: 0.381991, e: 5.842037, f: 0.092778)
        case (.sup3, .sceneExposure, 200): parameters = Parameters(cut: 0.006208, a: 5.555556, b: 0.076621, c: 0.266007, d: 0.382478, e: 5.776265, f: 0.092782)
        case (.sup3, .sceneExposure, 250): parameters = Parameters(cut: 0.006871, a: 5.555556, b: 0.072941, c: 0.262978, d: 0.382966, e: 5.710494, f: 0.092786)
        case (.sup3, .sceneExposure, 320): parameters = Parameters(cut: 0.007622, a: 5.555556, b: 0.068768, c: 0.259627, d: 0.383508, e: 5.637732, f: 0.092791)
        case (.sup3, .sceneExposure, 400): parameters = Parameters(cut: 0.008318, a: 5.555556, b: 0.064901, c: 0.256598, d: 0.383999, e: 5.571960, f: 0.092795)
        case (.sup3, .sceneExposure, 500): parameters = Parameters(cut: 0.009031, a: 5.555556, b: 0.060939, c: 0.253569, d: 0.384493, e: 5.506188, f: 0.092800)
        case (.sup3, .sceneExposure, 640): parameters = Parameters(cut: 0.009840, a: 5.555556, b: 0.056443, c: 0.250219, d: 0.385040, e: 5.433426, f: 0.092805)
        case (.sup3, .sceneExposure, 800): parameters = Parameters(cut: 0.010591, a: 5.555556, b: 0.052272, c: 0.247190, d: 0.385537, e: 5.367655, f: 0.092809)
        case (.sup3, .sceneExposure, 1000): parameters = Parameters(cut: 0.011361, a: 5.555556, b: 0.047996, c: 0.244161, d: 0.386036, e: 5.301883, f: 0.092814)
        case (.sup3, .sceneExposure, 1280): parameters = Parameters(cut: 0.012235, a: 5.555556, b: 0.043137, c: 0.240810, d: 0.386590, e: 5.229121, f: 0.092819)
        case (.sup3, .sceneExposure, 1600): parameters = Parameters(cut: 0.013047, a: 5.555556, b: 0.038625, c: 0.237781, d: 0.387093, e: 5.163350, f: 0.092824)
        case (.sup2, .sensorSignal, 160): parameters = Parameters(cut: 0.003907, a: 36.439829, b: -0.053366, c: 0.269035, d: 0.391007, e: 45.593473, f: -0.069772)
        case (.sup2, .sensorSignal, 200): parameters = Parameters(cut: 0.003907, a: 45.549786, b: -0.088959, c: 0.266007, d: 0.391007, e: 55.709581, f: -0.106114)
        case (.sup2, .sensorSignal, 250): parameters = Parameters(cut: 0.003907, a: 56.937232, b: -0.133449, c: 0.262978, d: 0.391007, e: 67.887153, f: -0.150510)
        case (.sup2, .sensorSignal, 320): parameters = Parameters(cut: 0.003907, a: 72.879657, b: -0.195737, c: 0.259627, d: 0.391007, e: 84.167616, f: -0.210597)
        case (.sup2, .sensorSignal, 400): parameters = Parameters(cut: 0.003907, a: 91.099572, b: -0.266922, c: 0.256598, d: 0.391007, e: 101.811426, f: -0.276349)
        case (.sup2, .sensorSignal, 500): parameters = Parameters(cut: 0.003907, a: 113.874465, b: -0.355903, c: 0.253569, d: 0.391007, e: 122.608379, f: -0.354421)
        case (.sup2, .sensorSignal, 640): parameters = Parameters(cut: 0.003907, a: 145.759315, b: -0.480477, c: 0.250218, d: 0.391007, e: 149.703304, f: -0.456760)
        case (.sup2, .sensorSignal, 800): parameters = Parameters(cut: 0.003907, a: 182.199144, b: -0.622848, c: 0.247189, d: 0.391007, e: 178.216873, f: -0.564981)
        case (.sup2, .sensorSignal, 1000): parameters = Parameters(cut: 0.003907, a: 227.748930, b: -0.800811, c: 0.244161, d: 0.391007, e: 210.785040, f: -0.689043)
        case (.sup2, .sensorSignal, 1280): parameters = Parameters(cut: 0.003907, a: 291.518630, b: -1.049959, c: 0.240810, d: 0.391007, e: 251.689459, f: -0.845336)
        case (.sup2, .sensorSignal, 1600): parameters = Parameters(cut: 0.003907, a: 364.398287, b: -1.334700, c: 0.237781, d: 0.391007, e: 293.073575, f: -1.003841)
        case (.sup2, .sceneExposure, 160): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.269035, d: 0.391007, e: 6.332427, f: 0.108361)
        case (.sup2, .sceneExposure, 200): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.266007, d: 0.391007, e: 6.189953, f: 0.111543)
        case (.sup2, .sceneExposure, 250): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.262978, d: 0.391007, e: 6.034414, f: 0.114725)
        case (.sup2, .sceneExposure, 320): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.259627, d: 0.391007, e: 5.844973, f: 0.118246)
        case (.sup2, .sceneExposure, 400): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.256598, d: 0.391007, e: 5.656190, f: 0.121428)
        case (.sup2, .sceneExposure, 500): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.253569, d: 0.391007, e: 5.449261, f: 0.124610)
        case (.sup2, .sceneExposure, 640): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.250218, d: 0.391007, e: 5.198031, f: 0.128130)
        case (.sup2, .sceneExposure, 800): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.247189, d: 0.391007, e: 4.950469, f: 0.131313)
        case (.sup2, .sceneExposure, 1000): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.244161, d: 0.391007, e: 4.684112, f: 0.134495)
        case (.sup2, .sceneExposure, 1280): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.240810, d: 0.391007, e: 4.369609, f: 0.138015)
        case (.sup2, .sceneExposure, 1600): parameters = Parameters(cut: 0.000000, a: 5.061087, b: 0.089004, c: 0.237781, d: 0.391007, e: 4.070466, f: 0.141197)
        default: throw Failure.unsupportedExposureIndex(exposureIndex)
        }
    }
    public func encode(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let p = parameters
        let result = linear > p.cut ? p.c * log10(p.a * linear + p.b) + p.d : p.e * linear + p.f
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
    public func decode(_ logC: Double) throws -> Double {
        guard logC.isFinite else { throw NumericError.nonFinite }
        let p = parameters
        let result = logC > p.encodedCut ? (pow(10, (logC - p.d) / p.c) - p.b) / p.a : (logC - p.f) / p.e
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
