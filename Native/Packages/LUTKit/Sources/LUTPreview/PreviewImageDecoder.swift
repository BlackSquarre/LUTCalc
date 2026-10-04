import Foundation
import CoreGraphics
import ImageIO
import LUTCore
import LUTFormats

public enum PreviewImageError: Error, Equatable, Sendable {
    case invalidImage
    case resourceLimit
    case unsupportedOrientation
    case unsupportedPixelLayout
    case unsupportedColorSpace
    case invalidICCProfile
}

/// Describes where the decoded color-space metadata came from.
/// This is provenance only; it never authorizes an implicit color conversion.
public enum PreviewColorSpaceProvenance: String, Equatable, Sendable {
    case sourceEmbeddedICC
    case sourceICCUnverified
}

public struct PreviewImage: Sendable {
    public let width: Int
    public let height: Int
    public let bitsPerComponent: Int
    public let alphaMode: AlphaMode
    public let decodedColorSpaceName: String?
    public let decodedICCProfile: Data?
    public let metadataProfileName: String?
    public let colorSpaceProvenance: PreviewColorSpaceProvenance
    /// The profile name ImageIO reports as embedded in the source, when known.
    /// This is deliberately separate from `decodedICCProfile`, which belongs to
    /// the decoded CGImage and may have been inferred or assigned by ImageIO.
    public let sourceEmbeddedICCProfileName: String?
    public let sourceEmbeddedICCProfile: Data?
    public let sourceICCValidation: ICCProfileValidation?
    public let pixels: [RGBA64]

    public func previewRequest(plan: TransformPlan, outputAlpha: AlphaMode,
                               identity: PreviewIdentity, postLUT: CubeLUT? = nil,
                               postLUTSettings: UserLUTPostStageSettings? = nil) throws -> PreviewRequest {
        try PreviewRequest(plan: plan, width: width, height: height, pixels: pixels,
                           inputAlpha: alphaMode, outputAlpha: outputAlpha, identity: identity,
                           postLUT: postLUT, postLUTSettings: postLUTSettings)
    }
}

public enum PreviewImageDecoder {
    public static let maxFileBytes = 256 * 1024 * 1024
    public static let maxDecodedBytes = 64 * 1024 * 1024

    public static func decode(url: URL) throws -> PreviewImage {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        } catch { throw PreviewImageError.invalidImage }
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let fileSize = values.fileSize else { throw PreviewImageError.invalidImage }
        guard fileSize <= maxFileBytes else { throw PreviewImageError.resourceLimit }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PreviewImageError.invalidImage
        }
        guard CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw PreviewImageError.invalidImage }
        let (count, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, count <= PreviewRequest.maxPixels else { throw PreviewImageError.resourceLimit }
        let orientation: Int
        if let rawOrientation = properties[kCGImagePropertyOrientation] {
            guard let parsed = rawOrientation as? Int else { throw PreviewImageError.unsupportedOrientation }
            orientation = parsed
        } else {
            orientation = 1
        }
        guard (1...8).contains(orientation) else { throw PreviewImageError.unsupportedOrientation }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == width, image.height == height else { throw PreviewImageError.invalidImage }
        let sourceICC: SourceICCProfile?
        do {
            sourceICC = try SourceICCReader.profile(from: url)
        } catch {
            throw PreviewImageError.invalidICCProfile
        }
        return orient(try decode(image: image, properties: properties, sourceICC: sourceICC), orientation: orientation)
    }

    private static func orient(_ source: PreviewImage, orientation: Int) -> PreviewImage {
        guard orientation != 1 else { return source }
        let rotated = orientation >= 5
        let width = rotated ? source.height : source.width
        let height = rotated ? source.width : source.height
        var pixels: [RGBA64] = []
        pixels.reserveCapacity(source.pixels.count)
        for y in 0..<height {
            for x in 0..<width {
                let sourceX: Int
                let sourceY: Int
                switch orientation {
                case 2: (sourceX, sourceY) = (source.width - 1 - x, y)
                case 3: (sourceX, sourceY) = (source.width - 1 - x, source.height - 1 - y)
                case 4: (sourceX, sourceY) = (x, source.height - 1 - y)
                case 5: (sourceX, sourceY) = (y, x)
                case 6: (sourceX, sourceY) = (y, source.height - 1 - x)
                case 7: (sourceX, sourceY) = (source.width - 1 - y, source.height - 1 - x)
                default: (sourceX, sourceY) = (source.width - 1 - y, x)
                }
                pixels.append(source.pixels[sourceX + source.width * sourceY])
            }
        }
        return PreviewImage(width: width, height: height, bitsPerComponent: source.bitsPerComponent,
                            alphaMode: source.alphaMode, decodedColorSpaceName: source.decodedColorSpaceName,
                            decodedICCProfile: source.decodedICCProfile,
                            metadataProfileName: source.metadataProfileName,
                            colorSpaceProvenance: source.colorSpaceProvenance,
                            sourceEmbeddedICCProfileName: source.sourceEmbeddedICCProfileName,
                            sourceEmbeddedICCProfile: source.sourceEmbeddedICCProfile,
                            sourceICCValidation: source.sourceICCValidation,
                            pixels: pixels)
    }

    private static func decode(image: CGImage, properties: [CFString: Any], sourceICC: SourceICCProfile?) throws -> PreviewImage {
        guard image.decode == nil else { throw PreviewImageError.unsupportedPixelLayout }
        guard let colorSpace = image.colorSpace,
              colorSpace.model == .rgb || colorSpace.model == .monochrome else {
            throw PreviewImageError.unsupportedColorSpace
        }
        let monochrome = colorSpace.model == .monochrome
        let depth = image.bitsPerComponent
        guard depth == 8 || depth == 16, image.bitsPerPixel % depth == 0 else {
            throw PreviewImageError.unsupportedPixelLayout
        }
        let channels = image.bitsPerPixel / depth
        let alphaMode: AlphaMode
        if monochrome {
            switch (channels, image.alphaInfo) {
            case (1, .none), (2, .noneSkipLast), (2, .last):
                alphaMode = .straight
            case (2, .premultipliedLast):
                alphaMode = .premultiplied
            default:
                throw PreviewImageError.unsupportedPixelLayout
            }
        } else {
            switch (channels, image.alphaInfo) {
            case (3, .none), (4, .noneSkipLast), (4, .last):
                alphaMode = .straight
            case (4, .premultipliedLast):
                alphaMode = .premultiplied
            default:
                throw PreviewImageError.unsupportedPixelLayout
            }
        }
        let byteOrder = image.bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue
        if depth == 8 {
            guard byteOrder == CGBitmapInfo.byteOrderDefault.rawValue else {
                throw PreviewImageError.unsupportedPixelLayout
            }
        } else {
            guard byteOrder == CGBitmapInfo.byteOrder16Big.rawValue ||
                    byteOrder == CGBitmapInfo.byteOrder16Little.rawValue else {
                throw PreviewImageError.unsupportedPixelLayout
            }
        }
        let bytesPerComponent = depth / 8
        let (rowBytes, rowOverflow) = image.width.multipliedReportingOverflow(by: channels * bytesPerComponent)
        let (totalBytes, totalOverflow) = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !rowOverflow, !totalOverflow, totalBytes <= maxDecodedBytes,
              image.bytesPerRow >= rowBytes,
              let providerData = image.dataProvider?.data,
              CFDataGetLength(providerData) >= totalBytes else {
            throw PreviewImageError.unsupportedPixelLayout
        }
        let data = providerData as Data
        let maximum = depth == 8 ? 255.0 : 65535.0
        var pixels: [RGBA64] = []
        pixels.reserveCapacity(image.width * image.height)
        try data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                throw PreviewImageError.invalidImage
            }
            func component(_ start: Int) -> Double {
                if depth == 8 { return Double(base[start]) / maximum }
                let first = Int(base[start])
                let second = Int(base[start + 1])
                let value = byteOrder == CGBitmapInfo.byteOrder16Big.rawValue
                    ? (first << 8) | second : (second << 8) | first
                return Double(value) / maximum
            }
            for y in 0..<image.height {
                let rowStart = y * image.bytesPerRow
                for x in 0..<image.width {
                    let start = rowStart + x * channels * bytesPerComponent
                    let rgb: RGB64
                    let alpha: Double
                    if monochrome {
                        let gray = component(start)
                        rgb = try RGB64(gray, gray, gray)
                        alpha = channels == 2 && image.alphaInfo != .noneSkipLast
                            ? component(start + bytesPerComponent) : 1
                    } else {
                        rgb = try RGB64(component(start), component(start + bytesPerComponent),
                                        component(start + 2 * bytesPerComponent))
                        alpha = image.alphaInfo == .none || image.alphaInfo == .noneSkipLast
                            ? 1 : component(start + 3 * bytesPerComponent)
                    }
                    pixels.append(try RGBA64(rgb: rgb, alpha: alpha))
                }
            }
        }
        let metadataProfileName = properties[kCGImagePropertyProfileName] as? String
        let embeddedProfileName = metadataProfileName ?? sourceICC?.name
        return PreviewImage(width: image.width, height: image.height,
                            bitsPerComponent: depth, alphaMode: alphaMode,
                            decodedColorSpaceName: colorSpace.name as String?,
                            decodedICCProfile: colorSpace.copyICCData() as Data?,
                            metadataProfileName: metadataProfileName,
                            colorSpaceProvenance: sourceICC == nil
                                ? .sourceICCUnverified : .sourceEmbeddedICC,
                            sourceEmbeddedICCProfileName: embeddedProfileName,
                            sourceEmbeddedICCProfile: sourceICC?.data,
                            sourceICCValidation: sourceICC?.validation,
                            pixels: pixels)
    }
}
