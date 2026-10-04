import Foundation

/// ACESproxy SDI encodings for 10-bit and 12-bit code words.
/// The public transfer is analytic; integer quantisation is left to the caller's
/// file or device interface and is never represented as a lookup table.
public enum ACESProxyBitDepth: Int, Codable, CaseIterable, Sendable {
    case ten = 10
    case twelve = 12

    fileprivate var maximumCode: Double { self == .ten ? 1023.0 : 4095.0 }
    fileprivate var blackCode: Double { self == .ten ? 64.0 : 256.0 }
    fileprivate var multiplier: Double { self == .ten ? 50.0 : 200.0 }
    fileprivate var offset: Double { self == .ten ? 425.0 : 1700.0 }
}

public struct ACESProxyTransfer: Equatable, Sendable {
    public static let referenceURL = "https://docs.acescentral.com/encodings/acesproxy/"

    public static let ten = ACESProxyTransfer(bitDepth: .ten)
    public static let twelve = ACESProxyTransfer(bitDepth: .twelve)

    public let bitDepth: ACESProxyBitDepth
    public let lowLinear: Double

    public init(bitDepth: ACESProxyBitDepth) {
        self.bitDepth = bitDepth
        lowLinear = pow(2.0, -9.72) / 0.9
    }

    public func encodeLinearAP1ToData(_ linear: Double) throws -> Double {
        guard linear.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if linear <= lowLinear {
            result = bitDepth.blackCode / bitDepth.maximumCode
        } else {
            result = (((log2(linear * 0.9) + 2.5) * bitDepth.multiplier) + bitDepth.offset)
                / bitDepth.maximumCode
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func decodeDataToLinearAP1(_ encoded: Double) throws -> Double {
        guard encoded.isFinite else { throw NumericError.nonFinite }
        let result = exp2(((encoded * bitDepth.maximumCode - bitDepth.offset)
                           / bitDepth.multiplier) - 2.5) / 0.9
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
