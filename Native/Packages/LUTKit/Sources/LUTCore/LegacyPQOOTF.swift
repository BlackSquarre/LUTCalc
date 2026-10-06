import Foundation

/// The historical LUTCalc PQ OOTF path, preserved as a compatibility kernel.
///
/// This is intentionally separate from `PQTransfer`: the legacy path uses a
/// percent-like linear input, a fixed BT.709-style encoding knee, and the
/// original `s` scale factors. It is not claimed to be a complete BT.2100
/// scene-to-display OOTF. The discontinuity at the historical knee is part of
/// this compatibility identity and is not smoothed.
public struct LegacyPQOOTF: Sendable, Equatable {
    public enum Scale: String, Codable, Sendable {
        case nits
        case normalized

        fileprivate var factor: Double {
            switch self {
            case .nits: 100.0
            case .normalized: 0.01
            }
        }
    }

    public enum Side: String, Codable, Sendable {
        case input
        case output
    }

    public static let dataScale = 0.85630498533724
    public static let dataOffset = 0.06256109481916
    public static let knee = 0.0003024
    public static let toeSlope = 267.84
    public static let logScale = 59.5208
    public static let logGain = 1.099
    public static let logOffset = 0.099
    public static let power = 2.4

    public let inputPeakNits: Double
    public let outputPeakNits: Double
    public let scale: Scale

    public init(inputPeakNits: Double, outputPeakNits: Double,
                scale: Scale = .nits) throws {
        guard inputPeakNits.isFinite, outputPeakNits.isFinite,
              inputPeakNits > 0, outputPeakNits > 0 else {
            throw NumericError.invalidDomain
        }
        self.inputPeakNits = inputPeakNits
        self.outputPeakNits = outputPeakNits
        self.scale = scale
    }

    public func forward(_ input: Double, side: Side) throws -> Double {
        guard input.isFinite else { throw NumericError.nonFinite }
        let peak = peak(for: side) / 100.0
        let value: Double
        if input < 0 {
            value = 0
        } else {
            let normalized = input / 100.0
            let encoded: Double
            if normalized > Self.knee {
                encoded = Self.logGain * pow(Self.logScale * normalized, 0.45) - Self.logOffset
            } else {
                encoded = Self.toeSlope * max(normalized, 0)
            }
            value = min(peak, pow(encoded, Self.power)) * scale.factor
        }
        guard value.isFinite else { throw NumericError.nonFinite }
        return value
    }

    public func inverse(_ display: Double, side: Side) throws -> Double {
        guard display.isFinite else { throw NumericError.nonFinite }
        let peak = peak(for: side) / 100.0 * scale.factor
        let zero = 0.0
        guard display >= 0, display <= peak else { throw NumericError.invalidDomain }
        guard display > zero else { return 0 }

        var encoded = pow(display / scale.factor, 1.0 / Self.power)
        if encoded > 0.080994816 {
            encoded = pow((encoded + Self.logOffset) / Self.logGain, 1.0 / 0.45) / Self.logScale
        } else {
            encoded /= Self.toeSlope
        }
        let result = encoded * 100.0
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func forwardData(_ input: Double, side: Side) throws -> Double {
        let legal = try forward(input, side: side)
        let result = legal * Self.dataScale + Self.dataOffset
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public func inverseData(_ data: Double, side: Side) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        return try inverse((data - Self.dataOffset) / Self.dataScale, side: side)
    }

    private func peak(for side: Side) -> Double {
        switch side {
        case .input: inputPeakNits
        case .output: outputPeakNits
        }
    }
}
