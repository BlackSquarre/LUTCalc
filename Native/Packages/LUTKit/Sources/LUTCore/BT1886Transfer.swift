import Foundation

/// ITU-R BT.1886 display EOTF with explicit black and white luminance.
///
/// The transfer is kept as a scalar display-domain operation. It does not
/// provide an HDR peak, OOTF, or color-space conversion.
public struct BT1886Transfer: Sendable, Equatable {
    public static let referenceURL = "https://www.itu.int/rec/R-REC-BT.1886/en"
    public static let gamma = 2.4
    public static let `default` = try! BT1886Transfer(blackLevel: 0, whiteLevel: 1, gamma: gamma)

    public let blackLevel: Double
    public let whiteLevel: Double
    public let gamma: Double
    private let blackRoot: Double
    private let whiteRoot: Double
    private let rootSpan: Double

    public init(blackLevel: Double, whiteLevel: Double, gamma: Double) throws {
        guard blackLevel.isFinite, whiteLevel.isFinite, gamma.isFinite,
              blackLevel >= 0, whiteLevel > blackLevel, gamma > 0 else {
            throw NumericError.invalidDomain
        }
        let blackRoot = pow(blackLevel, 1 / gamma)
        let whiteRoot = pow(whiteLevel, 1 / gamma)
        let rootSpan = whiteRoot - blackRoot
        guard blackRoot.isFinite, whiteRoot.isFinite, rootSpan.isFinite, rootSpan > 0 else {
            throw NumericError.invalidDomain
        }
        self.blackLevel = blackLevel
        self.whiteLevel = whiteLevel
        self.gamma = gamma
        self.blackRoot = blackRoot
        self.whiteRoot = whiteRoot
        self.rootSpan = rootSpan
    }

    public static func encodeDisplayToLuminance(_ display: Double) throws -> Double {
        try `default`.encodeDisplayToLuminance(display)
    }

    public static func decodeLuminanceToDisplay(_ luminance: Double) throws -> Double {
        try `default`.decodeLuminanceToDisplay(luminance)
    }

    public static func encodeSignalToLuminance(_ signal: Double,
                                               whiteLuminance: Double,
                                               blackLuminance: Double) throws -> Double {
        try BT1886Transfer(blackLevel: blackLuminance,
                           whiteLevel: whiteLuminance,
                           gamma: gamma).encodeDisplayToLuminance(signal)
    }

    public static func decodeLuminanceToSignal(_ luminance: Double,
                                               whiteLuminance: Double,
                                               blackLuminance: Double) throws -> Double {
        try BT1886Transfer(blackLevel: blackLuminance,
                           whiteLevel: whiteLuminance,
                           gamma: gamma).decodeLuminanceToDisplay(luminance)
    }

    public func encodeDisplayToLuminance(_ display: Double) throws -> Double {
        guard display.isFinite else { throw NumericError.nonFinite }
        guard (0...1).contains(display) else {
            throw NumericError.invalidDomain
        }
        if display == 0 { return blackLevel }
        if display == 1 { return whiteLevel }
        let result = pow(rootSpan * display + blackRoot, gamma)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeLuminanceToDisplay(_ luminance: Double) throws -> Double {
        guard luminance.isFinite else { throw NumericError.nonFinite }
        guard (blackLevel...whiteLevel).contains(luminance) else {
            throw NumericError.invalidDomain
        }
        if luminance == blackLevel { return 0 }
        if luminance == whiteLevel { return 1 }
        let result = (pow(luminance, 1 / gamma) - blackRoot) / rootSpan
        guard result.isFinite, (0...1).contains(result) else {
            throw NumericError.nonFinite
        }
        return result
    }
}
