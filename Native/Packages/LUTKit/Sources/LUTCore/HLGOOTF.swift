import Foundation

/// BT.2100 HLG display OOTF with explicit peak, black level and scale.
///
/// This is a display-domain operation. It is kept separate from `HLGTransfer`
/// so scene OETF values are never mistaken for display luminance. The scalar
/// and RGB forms follow the historical LUTCalc HLG OOTF equations while
/// retaining Double values through the complete calculation.
public struct HLGOOTF: Sendable, Equatable {
    public enum Scale: String, Codable, Sendable {
        case nits
        case normalizedBy1000

        fileprivate var factor: Double { self == .nits ? 1 : 0.001 }
    }

    public enum Side: String, Codable, Sendable {
        case input
        case output
    }

    public static let bbcCoefficient = 2.821251498
    public static let lumaR = 0.2627
    public static let lumaG = 0.6780
    public static let lumaB = 0.0593

    public let inputPeakNits: Double
    public let outputPeakNits: Double
    public let inputBlackNits: Double
    public let outputBlackNits: Double
    public let scale: Scale
    public let bbcInput: Bool
    public let bbcOutput: Bool

    private let inputGamma: Double
    private let outputGamma: Double
    private let inputA: Double
    private let outputA: Double
    private let inputBlack: Double
    private let outputBlack: Double
    private let factor: Double

    public init(inputPeakNits: Double, outputPeakNits: Double,
                inputBlackNits: Double, outputBlackNits: Double,
                scale: Scale = .nits, bbcInput: Bool = false,
                bbcOutput: Bool = false) throws {
        let values = [inputPeakNits, outputPeakNits, inputBlackNits, outputBlackNits]
        guard values.allSatisfy(\.isFinite), inputPeakNits > 0, outputPeakNits > 0,
              inputBlackNits >= 0, outputBlackNits >= 0,
              inputBlackNits < inputPeakNits, outputBlackNits < outputPeakNits else {
            throw NumericError.invalidDomain
        }
        let factor = scale.factor
        let inputGamma = Self.gamma(forPeak: inputPeakNits)
        let outputGamma = Self.gamma(forPeak: outputPeakNits)
        let inputA = (inputPeakNits - inputBlackNits) / pow(12, inputGamma)
        let outputA = (outputPeakNits - outputBlackNits) / pow(12, outputGamma)
        guard inputGamma.isFinite, outputGamma.isFinite, inputA.isFinite, outputA.isFinite,
              inputA > 0, outputA > 0 else { throw NumericError.invalidDomain }
        self.inputPeakNits = inputPeakNits
        self.outputPeakNits = outputPeakNits
        self.inputBlackNits = inputBlackNits
        self.outputBlackNits = outputBlackNits
        self.scale = scale
        self.bbcInput = bbcInput
        self.bbcOutput = bbcOutput
        self.inputGamma = inputGamma
        self.outputGamma = outputGamma
        self.inputA = inputA
        self.outputA = outputA
        self.inputBlack = inputBlackNits
        self.outputBlack = outputBlackNits
        self.factor = factor
    }

    private static func gamma(forPeak peak: Double) -> Double {
        1.2 + 0.42 * log10(peak / 1000)
    }

    private func parameters(for side: Side) -> (peak: Double, gamma: Double, a: Double, black: Double, bbc: Double) {
        switch side {
        case .input:
            (inputPeakNits, inputGamma, inputA, inputBlack, bbcInput ? Self.bbcCoefficient : 1)
        case .output:
            (outputPeakNits, outputGamma, outputA, outputBlack, bbcOutput ? Self.bbcCoefficient : 1)
        }
    }

    public func sceneToDisplay(_ scene: Double, side: Side) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: side)
        let result = min(p.peak * factor,
                         (p.a * pow(max(0, scene * p.bbc), p.gamma) + p.black) * factor)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func displayToScene(_ display: Double, side: Side) throws -> Double {
        guard display.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: side)
        guard display >= 0, display < p.peak * factor else { throw NumericError.invalidDomain }
        let result = pow(max(0, (display / factor) - p.black) / p.a, 1 / p.gamma) / p.bbc
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func sceneRGBToDisplay(_ scene: RGB64, side: Side) throws -> RGB64 {
        guard scene.r.isFinite, scene.g.isFinite, scene.b.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: side)
        let r = max(0, scene.r) * p.bbc
        let g = max(0, scene.g) * p.bbc
        let b = max(0, scene.b) * p.bbc
        let y = Self.lumaR * r + Self.lumaG * g + Self.lumaB * b
        // The continuous RGB OOTF limit is the display black, including
        // gamma < 1 where the unreduced expression is infinity times zero.
        if r == 0 && g == 0 && b == 0 {
            let black = p.black * self.factor
            return try RGB64(black, black, black)
        }
        let factor = p.a * pow(y, p.gamma - 1)
        let result = try RGB64(min(p.peak * self.factor, (factor * r + p.black) * self.factor),
                               min(p.peak * self.factor, (factor * g + p.black) * self.factor),
                               min(p.peak * self.factor, (factor * b + p.black) * self.factor))
        guard result.r.isFinite, result.g.isFinite, result.b.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func displayRGBToScene(_ display: RGB64, side: Side) throws -> RGB64 {
        guard display.r.isFinite, display.g.isFinite, display.b.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: side)
        let peak = p.peak * factor
        let black = p.black * factor
        guard [display.r, display.g, display.b].allSatisfy({ (black...peak).contains($0) }) else {
            throw NumericError.invalidDomain
        }
        // A peak-clipped channel has infinitely many scene values and cannot
        // be recovered by this inverse. Reject it instead of returning a
        // plausible but non-unique result.
        guard display.r < peak, display.g < peak, display.b < peak else {
            throw NumericError.invalidDomain
        }
        if display.r == black && display.g == black && display.b == black {
            return try RGB64(0, 0, 0)
        }
        let y = Self.lumaR * display.r + Self.lumaG * display.g + Self.lumaB * display.b
        let luminance = pow(max(0, (y / self.factor) - p.black) / p.a, (1 - p.gamma) / p.gamma) / (p.a * p.bbc)
        let r = luminance * ((display.r / self.factor) - p.black)
        let g = luminance * ((display.g / self.factor) - p.black)
        let b = luminance * ((display.b / self.factor) - p.black)
        let result = try RGB64(r, g, b)
        guard result.r.isFinite, result.g.isFinite, result.b.isFinite else { throw NumericError.nonFinite }
        return result
    }
}

/// Persisted parameters for the HLG display OOTF.
///
/// The payload deliberately keeps the input and output display sides
/// separate.  The current TransformPlan composition uses the output side
/// when an HLG output transfer is selected; the input side remains part of
/// the stable contract for reverse/display-domain callers.
public struct HLGOOTFSettings: Sendable, Equatable, Codable {
    public enum Algorithm: String, Sendable, Codable {
        case lutcalcHLGOOTFV1 = "lutcalc.hlg-ootf-display.v1"
    }

    public let algorithm: Algorithm
    public let enabled: Bool
    public let inputPeakNits: Double
    public let outputPeakNits: Double
    public let inputBlackNits: Double
    public let outputBlackNits: Double
    public let scale: HLGOOTF.Scale
    public let bbcInput: Bool
    public let bbcOutput: Bool

    public init(enabled: Bool = true,
                inputPeakNits: Double = 1000,
                outputPeakNits: Double = 1000,
                inputBlackNits: Double = 0,
                outputBlackNits: Double = 0,
                scale: HLGOOTF.Scale = .normalizedBy1000,
                bbcInput: Bool = false,
                bbcOutput: Bool = false,
                algorithm: Algorithm = .lutcalcHLGOOTFV1) {
        self.algorithm = algorithm
        self.enabled = enabled
        self.inputPeakNits = inputPeakNits
        self.outputPeakNits = outputPeakNits
        self.inputBlackNits = inputBlackNits
        self.outputBlackNits = outputBlackNits
        self.scale = scale
        self.bbcInput = bbcInput
        self.bbcOutput = bbcOutput
    }

    public func makeKernel() throws -> HLGOOTF {
        try HLGOOTF(inputPeakNits: inputPeakNits,
                    outputPeakNits: outputPeakNits,
                    inputBlackNits: inputBlackNits,
                    outputBlackNits: outputBlackNits,
                    scale: scale,
                    bbcInput: bbcInput,
                    bbcOutput: bbcOutput)
    }
}
