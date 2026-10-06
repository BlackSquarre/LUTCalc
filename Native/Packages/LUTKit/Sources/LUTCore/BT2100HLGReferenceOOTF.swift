import Foundation

/// BT.2100-3 HLG reference OOTF for normalized scene-linear RGB.
///
/// This is the reference OOTF from Table 5, before the HLG EOTF black-level
/// lift. Scene white is 1.0 and output values are absolute cd/m2. The older
/// `HLGOOTF` type intentionally remains separate because it preserves the
/// historical LUTCalc 0...12 scene convention and black-level parameters.
public struct BT2100HLGReferenceOOTF: Equatable, Sendable {
    public enum GammaMode: String, Codable, Sendable {
        case usualProductionRange
        case extended
    }

    public static let referenceURL = "ITU-R BT.2100-3 (02/2025), Table 5 and Note 5f"
    public static let lumaR = 0.2627
    public static let lumaG = 0.6780
    public static let lumaB = 0.0593
    public static let extendedGammaKappa = 1.111

    public let peakLuminanceNits: Double
    public let systemGamma: Double
    public let gammaMode: GammaMode

    /// Creates the nominal-range reference OOTF. BT.2100-3 gives the
    /// logarithmic system-gamma formula for the usual 400...2000 cd/m2
    /// monitoring range. Extended-range gamma must be selected explicitly.
    public init(peakLuminanceNits: Double) throws {
        try self.init(peakLuminanceNits: peakLuminanceNits,
                      gammaMode: .usualProductionRange)
    }

    /// Creates the reference OOTF with the system-gamma policy from
    /// BT.2100-3 Note 5f. The extended formula is only used when explicitly
    /// requested; it must not be inferred from a nominal-range setting.
    public init(peakLuminanceNits: Double, gammaMode: GammaMode) throws {
        guard peakLuminanceNits.isFinite, peakLuminanceNits > 0 else {
            throw NumericError.invalidDomain
        }
        let gamma: Double
        switch gammaMode {
        case .usualProductionRange:
            guard (400.0...2000.0).contains(peakLuminanceNits) else {
                throw NumericError.invalidDomain
            }
            gamma = 1.2 + 0.42 * log10(peakLuminanceNits / 1000.0)
        case .extended:
            gamma = 1.2 * Foundation.pow(
                Self.extendedGammaKappa,
                Foundation.log2(peakLuminanceNits / 1000.0)
            )
        }
        guard gamma.isFinite, gamma > 0 else { throw NumericError.invalidDomain }
        self.peakLuminanceNits = peakLuminanceNits
        self.systemGamma = gamma
        self.gammaMode = gammaMode
    }

    /// Applies `F_D = L_W * Y_S^(gamma - 1) * E` to one achromatic channel.
    public func sceneToDisplay(_ scene: Double) throws -> Double {
        guard scene.isFinite, scene >= 0 else { throw NumericError.invalidDomain }
        let result = peakLuminanceNits * pow(scene, systemGamma)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    /// Inverse of the scalar reference OOTF. Peak clipping is not performed;
    /// the caller must keep the display value in the finite reference domain.
    public func displayToScene(_ display: Double) throws -> Double {
        guard display.isFinite, display >= 0 else { throw NumericError.invalidDomain }
        let result = pow(display / peakLuminanceNits, 1.0 / systemGamma)
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    /// Applies the RGB form of the reference OOTF without clipping negative
    /// components. A non-negative scene luminance is required by the real
    /// power law; negative chromatic components remain representable.
    public func sceneRGBToDisplay(_ scene: RGB64) throws -> RGB64 {
        guard scene.r.isFinite, scene.g.isFinite, scene.b.isFinite else {
            throw NumericError.nonFinite
        }
        let luminance = Self.lumaR * scene.r + Self.lumaG * scene.g + Self.lumaB * scene.b
        guard luminance.isFinite, luminance >= 0 else { throw NumericError.invalidDomain }
        let scale = peakLuminanceNits * pow(luminance, systemGamma - 1.0)
        guard scale.isFinite else { throw NumericError.nonFinite }
        if luminance == 0 {
            return try RGB64(0, 0, 0)
        }
        return try RGB64(scale * scene.r, scale * scene.g, scale * scene.b)
    }

    /// Inverse RGB reference OOTF. The zero-luminance output is only uniquely
    /// invertible when every display component is zero.
    public func displayRGBToScene(_ display: RGB64) throws -> RGB64 {
        guard display.r.isFinite, display.g.isFinite, display.b.isFinite else {
            throw NumericError.nonFinite
        }
        let luminance = Self.lumaR * display.r + Self.lumaG * display.g + Self.lumaB * display.b
        guard luminance.isFinite, luminance >= 0 else { throw NumericError.invalidDomain }
        if luminance == 0 {
            guard display.r == 0, display.g == 0, display.b == 0 else {
                throw NumericError.invalidDomain
            }
            return try RGB64(0, 0, 0)
        }
        let sceneLuminance = pow(luminance / peakLuminanceNits, 1.0 / systemGamma)
        let scale = peakLuminanceNits * pow(sceneLuminance, systemGamma - 1.0)
        guard sceneLuminance.isFinite, scale.isFinite, scale > 0 else {
            throw NumericError.nonFinite
        }
        return try RGB64(display.r / scale, display.g / scale, display.b / scale)
    }

    /// BT.2100-3 Table 5 reference EOTF black-level lift. The encoded HLG
    /// signal is lifted before the HLG inverse OETF and reference OOTF are
    /// applied. The reference formula requires a finite black below the
    /// nominal peak and a lift smaller than one so the inverse remains unique.
    public func blackLevelLift(blackLuminanceNits: Double) throws -> Double {
        guard blackLuminanceNits.isFinite,
              blackLuminanceNits >= 0,
              blackLuminanceNits < peakLuminanceNits else {
            throw NumericError.invalidDomain
        }
        let beta = Foundation.sqrt(3.0)
            * Foundation.pow(blackLuminanceNits / peakLuminanceNits, 1.0 / systemGamma)
        guard beta.isFinite, beta >= 0, beta < 1 else {
            throw NumericError.invalidDomain
        }
        return beta
    }

    /// BT.2100 reference HLG EOTF for one encoded component. Values outside
    /// the nominal encoded range remain available for production headroom;
    /// the standard's lower bound is applied only after the black lift.
    public func encodedHLGToDisplay(_ encoded: Double,
                                   blackLuminanceNits: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let beta = try blackLevelLift(blackLuminanceNits: blackLuminanceNits)
        let lifted = max(0.0, (1.0 - beta) * encoded + beta)
        let scene = try HLGTransfer.decodeDataToScene(lifted)
        return try sceneToDisplay(scene)
    }

    /// Display luminance at nominal encoded black (`E' = 0`). Negative HLG
    /// headroom remains below this anchor; only a zero display result is
    /// folded by the `max(0, ...)` term and has no unique inverse.
    public func displayBlackLevel(blackLuminanceNits: Double) throws -> Double {
        _ = try blackLevelLift(blackLuminanceNits: blackLuminanceNits)
        let result = blackLuminanceNits * blackLuminanceNits / peakLuminanceNits
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    /// Inverse of `encodedHLGToDisplay`. A display black maps to the negative
    /// pre-lift encoded value required to produce a lifted zero; it is not
    /// silently clamped to the nominal HLG range.
    public func displayToEncodedHLG(_ display: Double,
                                   blackLuminanceNits: Double) throws -> Double {
        guard display.isFinite else { throw NumericError.nonFinite }
        let beta = try blackLevelLift(blackLuminanceNits: blackLuminanceNits)
        guard display > 0 else { throw NumericError.invalidDomain }
        let scene = try displayToScene(display)
        let encodedScene = try HLGTransfer.encodeSceneToData(scene)
        let encoded = (encodedScene - beta) / (1.0 - beta)
        guard encoded.isFinite else { throw NumericError.nonFinite }
        return encoded
    }

    /// RGB reference HLG EOTF. The black lift is applied per encoded
    /// component, then the resulting scene RGB is passed through the same
    /// luminance-coupled reference OOTF as the direct scene API.
    public func encodedHLGRGBToDisplay(_ encoded: RGB64,
                                      blackLuminanceNits: Double) throws -> RGB64 {
        guard encoded.r.isFinite, encoded.g.isFinite, encoded.b.isFinite else {
            throw NumericError.nonFinite
        }
        let beta = try blackLevelLift(blackLuminanceNits: blackLuminanceNits)
        let scale = 1.0 - beta
        let lifted = try RGB64(
            max(0.0, scale * encoded.r + beta),
            max(0.0, scale * encoded.g + beta),
            max(0.0, scale * encoded.b + beta)
        )
        let scene = try RGB64(
            HLGTransfer.decodeDataToScene(lifted.r),
            HLGTransfer.decodeDataToScene(lifted.g),
            HLGTransfer.decodeDataToScene(lifted.b)
        )
        return try sceneRGBToDisplay(scene)
    }

    /// Inverse RGB reference HLG EOTF with the same explicit black lift.
    public func displayRGBToEncodedHLG(_ display: RGB64,
                                      blackLuminanceNits: Double) throws -> RGB64 {
        guard display.r.isFinite, display.g.isFinite, display.b.isFinite else {
            throw NumericError.nonFinite
        }
        let beta = try blackLevelLift(blackLuminanceNits: blackLuminanceNits)
        guard display.r > 0, display.g > 0, display.b > 0 else {
            throw NumericError.invalidDomain
        }
        let scene = try displayRGBToScene(display)
        let encodedScene = try RGB64(
            HLGTransfer.encodeSceneToData(scene.r),
            HLGTransfer.encodeSceneToData(scene.g),
            HLGTransfer.encodeSceneToData(scene.b)
        )
        let scale = 1.0 - beta
        return try RGB64(
            (encodedScene.r - beta) / scale,
            (encodedScene.g - beta) / scale,
            (encodedScene.b - beta) / scale
        )
    }
}
