public enum NumericError: Error, Equatable, Sendable {
    case nonFinite
    case invalidCodeRange
    case invalidDomain
    case invalidGridSize
    case sizeOverflow
    case indexOutOfBounds
}

public struct RGB64: Equatable, Hashable, Codable, Sendable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) throws {
        guard r.isFinite, g.isFinite, b.isFinite else { throw NumericError.nonFinite }
        self.r = r
        self.g = g
        self.b = b
    }

    public subscript(_ channel: Int) -> Double {
        switch channel {
        case 0: r
        case 1: g
        case 2: b
        default: preconditionFailure("RGB channel outside 0...2")
        }
    }
}

public struct CodeRange: Equatable, Sendable {
    public let bitDepth: Int
    public let blackCode: Int
    public let whiteCode: Int
    public let maxCode: Int

    public init(bitDepth: Int, blackCode: Int, whiteCode: Int, maxCode: Int) throws {
        guard (1...30).contains(bitDepth),
              maxCode == (1 << bitDepth) - 1,
              0 <= blackCode, blackCode < whiteCode, whiteCode <= maxCode else {
            throw NumericError.invalidCodeRange
        }
        self.bitDepth = bitDepth
        self.blackCode = blackCode
        self.whiteCode = whiteCode
        self.maxCode = maxCode
    }

    public static func videoRGB(bitDepth: Int) throws -> CodeRange {
        switch bitDepth {
        case 8: try CodeRange(bitDepth: 8, blackCode: 16, whiteCode: 235, maxCode: 255)
        case 10: try CodeRange(bitDepth: 10, blackCode: 64, whiteCode: 940, maxCode: 1023)
        case 12: try CodeRange(bitDepth: 12, blackCode: 256, whiteCode: 3760, maxCode: 4095)
        default: throw NumericError.invalidCodeRange
        }
    }

    public func videoToData(_ video: Double) throws -> Double {
        guard video.isFinite else { throw NumericError.nonFinite }
        let data = (video * Double(whiteCode - blackCode) + Double(blackCode)) / Double(maxCode)
        guard data.isFinite else { throw NumericError.nonFinite }
        return data
    }

    public func dataToVideo(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let video = (data * Double(maxCode) - Double(blackCode)) / Double(whiteCode - blackCode)
        guard video.isFinite else { throw NumericError.nonFinite }
        return video
    }
}

public enum LinearReference: String, Codable, Sendable {
    case legacyGrey02
    case sceneReflectance
    case absoluteNits
}

public enum LinearScale {
    public static func legacyToScene(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value * 0.9
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func sceneToLegacy(_ value: Double) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value / 0.9
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}

public struct LUTDomain: Equatable, Codable, Sendable {
    public let min: RGB64
    public let max: RGB64

    public init(min: RGB64, max: RGB64) throws {
        guard min.r < max.r, min.g < max.g, min.b < max.b else {
            throw NumericError.invalidDomain
        }
        self.min = min
        self.max = max
    }

    public static var unit: LUTDomain {
        try! LUTDomain(min: RGB64(0, 0, 0), max: RGB64(1, 1, 1))
    }
}

public struct Grid3D: Sendable {
    public let size: Int
    public let domain: LUTDomain
    public let nodeCount: Int
    public let rgbDoubleBytes: Int

    public init(size: Int, domain: LUTDomain) throws {
        guard size >= 2 else { throw NumericError.invalidGridSize }
        let (square, overflowSquare) = size.multipliedReportingOverflow(by: size)
        let (cube, overflowCube) = square.multipliedReportingOverflow(by: size)
        let (channels, overflowChannels) = cube.multipliedReportingOverflow(by: 3)
        let (bytes, overflowBytes) = channels.multipliedReportingOverflow(by: MemoryLayout<Double>.stride)
        guard !overflowSquare, !overflowCube, !overflowChannels, !overflowBytes else {
            throw NumericError.sizeOverflow
        }
        self.size = size
        self.domain = domain
        self.nodeCount = cube
        self.rgbDoubleBytes = bytes
    }

    public func nodeIndex(r: Int, g: Int, b: Int) throws -> Int {
        guard (0..<size).contains(r), (0..<size).contains(g), (0..<size).contains(b) else {
            throw NumericError.indexOutOfBounds
        }
        return r + size * (g + size * b)
    }

    public func channelOffset(r: Int, g: Int, b: Int, channel: Int) throws -> Int {
        guard (0...2).contains(channel) else { throw NumericError.indexOutOfBounds }
        return 3 * (try nodeIndex(r: r, g: g, b: b)) + channel
    }

    public func coordinate(at index: Int) throws -> RGB64 {
        guard (0..<nodeCount).contains(index) else { throw NumericError.indexOutOfBounds }
        let r = index % size
        let g = (index / size) % size
        let b = index / (size * size)
        let denominator = Double(size - 1)
        return try RGB64(
            domain.min.r + Double(r) / denominator * (domain.max.r - domain.min.r),
            domain.min.g + Double(g) / denominator * (domain.max.g - domain.min.g),
            domain.min.b + Double(b) / denominator * (domain.max.b - domain.min.b)
        )
    }
}
