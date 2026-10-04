import Foundation
import CoreGraphics
import LUTCore
import LUTFormats

public enum PreviewError: Error, Equatable, Sendable {
    case invalidDimensions
    case invalidAlpha
    case outsideImage
    case invalidIdentity
    case unsupportedDisplayTransfer(TransferID)
    case invalidDisplayBitmap
}

public enum AlphaMode: String, Sendable {
    case straight
    case premultiplied
}

public struct RGBA64: Equatable, Sendable {
    public let rgb: RGB64
    public let alpha: Double

    public init(rgb: RGB64, alpha: Double) throws {
        guard alpha.isFinite, (0...1).contains(alpha) else { throw PreviewError.invalidAlpha }
        self.rgb = rgb
        self.alpha = alpha
    }
}

public struct PreviewIdentity: Equatable, Hashable, Sendable {
    public let documentID: UUID
    public let revision: UInt64
    public let requestID: UUID
    public let planVersion: String

    public init(documentID: UUID, revision: UInt64, requestID: UUID, planVersion: String) {
        self.documentID = documentID
        self.revision = revision
        self.requestID = requestID
        self.planVersion = planVersion
    }
}

public struct PreviewRequest: Sendable {
    public static let maxPixels = 4_000_000
    public let plan: TransformPlan
    public let width: Int
    public let height: Int
    public let pixels: [RGBA64]
    public let inputAlpha: AlphaMode
    public let outputAlpha: AlphaMode
    public let identity: PreviewIdentity
    public let postLUT: CubeLUT?
    public let postLUTSettings: UserLUTPostStageSettings?
    private let postSampler: PreparedCubeSampler?

    public init(plan: TransformPlan, width: Int, height: Int, pixels: [RGBA64],
                inputAlpha: AlphaMode, outputAlpha: AlphaMode, identity: PreviewIdentity,
                postLUT: CubeLUT? = nil, postLUTSettings: UserLUTPostStageSettings? = nil) throws {
        guard width > 0, height > 0 else { throw PreviewError.invalidDimensions }
        let (count, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, count <= Self.maxPixels, count == pixels.count else {
            throw PreviewError.invalidDimensions
        }
        guard identity.planVersion == plan.planVersion else { throw PreviewError.invalidIdentity }
        self.plan = plan
        self.width = width
        self.height = height
        self.pixels = pixels
        self.inputAlpha = inputAlpha
        self.outputAlpha = outputAlpha
        self.identity = identity
        self.postLUT = postLUT
        guard postLUT != nil || postLUTSettings == nil else { throw NumericError.invalidDomain }
        if postLUTSettings?.outside == .legacyExtensionV1,
           postLUT?.dimension != .one || postLUTSettings?.interpolation != .tricubicLegacyV1 {
            throw VolumeError.unsupportedOutsidePolicy
        }
        self.postLUTSettings = postLUTSettings
        self.postSampler = try postLUT?.preparedSampler(interpolation: postLUTSettings?.interpolation ?? .trilinear)
    }

    fileprivate func applyPostStage(_ value: RGB64) throws -> RGB64 {
        try postSampler?.sample(value, outside: postLUTSettings?.outside ?? .reject) ?? value
    }
}

public struct PreviewSample: Sendable {
    public let source: RGBA64
    public let inputToPlan: RGB64
    public let planOutput: RGB64
    public let output: RGBA64
}

public struct PreviewResult: Sendable {
    public let settings: TransformSettings
    public let identity: PreviewIdentity
    public let inputAlpha: AlphaMode
    public let outputAlpha: AlphaMode
    public let width: Int
    public let height: Int
    public let pixels: [PreviewSample]

    public func sample(x: Int, y: Int) throws -> PreviewSample {
        guard (0..<width).contains(x), (0..<height).contains(y) else { throw PreviewError.outsideImage }
        return pixels[x + width * y]
    }
}

/// One display-ready sample. The encoded values are independent of the
/// numeric/export result and are clamped only at the final display encoding
/// boundary. They are not a source for LUT generation or numeric sampling.
public struct DisplayPreviewSample: Sendable {
    public let encodedRGB: RGB64
    public let alpha: Double

    public init(encodedRGB: RGB64, alpha: Double) throws {
        self.encodedRGB = encodedRGB
        guard alpha.isFinite, (0...1).contains(alpha) else { throw PreviewError.invalidAlpha }
        self.alpha = alpha
    }
}

public struct DisplayPreviewResult: Sendable {
    public let identity: PreviewIdentity
    public let sourceTransfer: TransferID
    public let sourceSpace: ColorSpaceID
    public let targetTransfer: TransferID
    public let targetSpace: ColorSpaceID
    public let outputAlpha: AlphaMode
    public let width: Int
    public let height: Int
    public let pixels: [DisplayPreviewSample]

    public func sample(x: Int, y: Int) throws -> DisplayPreviewSample {
        guard (0..<width).contains(x), (0..<height).contains(y) else { throw PreviewError.outsideImage }
        return pixels[x + width * y]
    }

    public func makeBitmap() throws -> DisplayPreviewBitmap {
        try DisplayPreviewBitmap(result: self)
    }
}

/// Explicit SDR display representation. Quantization happens only here and
/// never changes the Double preview or export values.
public struct DisplayPreviewBitmap: Sendable {
    public let width: Int
    public let height: Int
    public let rgba8: [UInt8]
    public let alphaMode: AlphaMode

    public init(result: DisplayPreviewResult) throws {
        let (count, overflow) = result.width.multipliedReportingOverflow(by: result.height)
        guard !overflow, count > 0, count == result.pixels.count,
              count <= PreviewRequest.maxPixels else {
            throw PreviewError.invalidDisplayBitmap
        }
        self.width = result.width
        self.height = result.height
        self.alphaMode = result.outputAlpha
        var bytes: [UInt8] = []
        bytes.reserveCapacity(count * 4)
        for (index, pixel) in result.pixels.enumerated() {
            if index & 4095 == 0 { try Task.checkCancellation() }
            let alpha = Self.quantize(pixel.alpha)
            if result.outputAlpha == .premultiplied {
                // A premultiplied RGBA8 pixel must keep every color byte at or
                // below its quantized alpha byte, even when a malformed sample
                // reaches this final display boundary.
                bytes.append(min(Self.quantize(pixel.encodedRGB.r), alpha))
                bytes.append(min(Self.quantize(pixel.encodedRGB.g), alpha))
                bytes.append(min(Self.quantize(pixel.encodedRGB.b), alpha))
            } else {
                bytes.append(Self.quantize(pixel.encodedRGB.r))
                bytes.append(Self.quantize(pixel.encodedRGB.g))
                bytes.append(Self.quantize(pixel.encodedRGB.b))
            }
            bytes.append(alpha)
        }
        self.rgba8 = bytes
    }

    #if canImport(CoreGraphics)
    public func cgImage() -> CGImage? {
        guard rgba8.count == width * height * 4,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let data = Data(rgba8) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        let alphaInfo: CGImageAlphaInfo = alphaMode == .premultiplied ? .premultipliedLast : .last
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: alphaInfo.rawValue))
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: colorSpace,
                       bitmapInfo: bitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
    #endif

    private static func quantize(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded(.toNearestOrEven)))
    }
}

public enum CPUPreview {
    public static func render(_ request: PreviewRequest) throws -> PreviewResult {
        var output: [PreviewSample] = []
        output.reserveCapacity(request.pixels.count)
        for (index, pixel) in request.pixels.enumerated() {
            if index & 4095 == 0 { try Task.checkCancellation() }
            let (input, evaluated) = try evaluate(pixel, in: request, at: index)
            let visible: RGB64
            if request.outputAlpha == .premultiplied {
                visible = try RGB64(evaluated.r * pixel.alpha,
                                    evaluated.g * pixel.alpha,
                                    evaluated.b * pixel.alpha)
            } else {
                visible = evaluated
            }
            output.append(PreviewSample(
                source: pixel, inputToPlan: input, planOutput: evaluated,
                output: try RGBA64(rgb: visible, alpha: pixel.alpha)
            ))
        }
        return PreviewResult(settings: request.plan.settings, identity: request.identity,
                             inputAlpha: request.inputAlpha, outputAlpha: request.outputAlpha,
                             width: request.width, height: request.height, pixels: output)
    }

    /// Renders the numeric result through an explicit, display-only transform.
    /// The project plan remains the sole source for numeric/export values.
    public static func renderDisplay(_ request: PreviewRequest) throws -> DisplayPreviewResult {
        let settings = request.plan.settings
        guard settings.outputTransfer != .rec2100HLG,
              settings.outputTransfer != .rec2100PQ else {
            throw PreviewError.unsupportedDisplayTransfer(settings.outputTransfer)
        }
        let displaySettings = TransformSettings(
            inputTransfer: settings.outputTransfer,
            outputTransfer: .linearScene,
            inputSpace: settings.outputSpace,
            outputSpace: .srgb,
            inputRange: settings.outputRange,
            outputRange: .data,
            exposureStops: 0,
            rangeBitDepth: settings.rangeBitDepth,
            adaptation: settings.adaptation
        )
        let displayPlan = try TransformPlan(settings: displaySettings)
        var displayPixels: [DisplayPreviewSample] = []
        displayPixels.reserveCapacity(request.pixels.count)
        for (index, pixel) in request.pixels.enumerated() {
            if index & 4095 == 0 { try Task.checkCancellation() }
            let (_, planOutput) = try evaluate(pixel, in: request, at: index)
            let linearSRGB = pixel.alpha == 0
                ? try RGB64(0, 0, 0)
                : try displayPlan.evaluate(planOutput, sampleIndex: index)
            let encoded = try RGB64(
                clamp(try SRGBTransfer.encode(linearSRGB.r, variant: .w3cExtended)),
                clamp(try SRGBTransfer.encode(linearSRGB.g, variant: .w3cExtended)),
                clamp(try SRGBTransfer.encode(linearSRGB.b, variant: .w3cExtended))
            )
            let visible: RGB64
            if request.outputAlpha == .premultiplied {
                visible = try RGB64(encoded.r * pixel.alpha,
                                    encoded.g * pixel.alpha,
                                    encoded.b * pixel.alpha)
            } else {
                visible = encoded
            }
            displayPixels.append(try DisplayPreviewSample(encodedRGB: visible, alpha: pixel.alpha))
        }
        return DisplayPreviewResult(identity: request.identity,
                                    sourceTransfer: settings.outputTransfer,
                                    sourceSpace: settings.outputSpace,
                                    targetTransfer: .srgbW3CExtended,
                                    targetSpace: .srgb,
                                    outputAlpha: request.outputAlpha,
                                    width: request.width, height: request.height,
                                    pixels: displayPixels)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func evaluate(_ pixel: RGBA64, in request: PreviewRequest,
                                 at index: Int) throws -> (RGB64, RGB64) {
        let input: RGB64
        if pixel.alpha == 0 {
            input = try RGB64(0, 0, 0)
        } else if request.inputAlpha == .premultiplied {
            input = try RGB64(pixel.rgb.r / pixel.alpha,
                              pixel.rgb.g / pixel.alpha,
                              pixel.rgb.b / pixel.alpha)
        } else {
            input = pixel.rgb
        }
        let output: RGB64
        if pixel.alpha == 0 {
            output = try RGB64(0, 0, 0)
        } else {
            let base = try request.plan.evaluate(input, sampleIndex: index)
            output = try request.applyPostStage(base)
        }
        return (input, output)
    }
}

public struct PreviewIdentityGate: Sendable {
    public let expected: PreviewIdentity
    public let active: Bool

    public init(expected: PreviewIdentity, active: Bool) {
        self.expected = expected
        self.active = active
    }

    public func accepts(_ result: PreviewResult) -> Bool { accepts(identity: result.identity) }

    public func accepts(identity: PreviewIdentity) -> Bool { active && identity == expected }
}

public actor PreviewSession {
    public let documentID: UUID
    private var current: PreviewIdentity?
    private var active = true

    public init(documentID: UUID) { self.documentID = documentID }

    public func begin(revision: UInt64, planVersion: String) throws -> PreviewIdentity {
        guard active, !planVersion.isEmpty,
              current.map({ revision >= $0.revision }) ?? true else {
            throw PreviewError.invalidIdentity
        }
        let identity = PreviewIdentity(documentID: documentID, revision: revision,
                                       requestID: UUID(), planVersion: planVersion)
        current = identity
        return identity
    }

    public func accepts(_ identity: PreviewIdentity) -> Bool {
        guard let current else { return false }
        return PreviewIdentityGate(expected: current, active: active).accepts(identity: identity)
    }

    public func accepts(_ result: PreviewResult) -> Bool { accepts(result.identity) }

    public func close() {
        active = false
        current = nil
    }
}
