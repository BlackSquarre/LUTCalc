import Foundation

/// Scalar-only legacy LUTGammaLog registrations whose gamut metadata is not
/// sufficient to define a native published camera colour model.
public enum LegacyRegisteredLogTransfer {
    public enum Variant: String, Sendable { case bolex, panalog, djiX5, protune }
    private struct P { let slope: Double; let intercept: Double; let logScale: Double; let inputScale: Double; let logBase: Double; let logOffset: Double; let inputOffset: Double; let decodeCut: Double; let encodeCut: Double }
    private static func p(_ v: Variant) -> P {
        switch v {
        case .bolex: return P(slope: 1 / (5.9861078 * 0.9), intercept: -0.0625265 / (0.9 * 5.9861078), logScale: 0.2756705, inputScale: 5, logBase: 10, logOffset: 0.4150634, inputOffset: 0.0280665, decodeCut: 0.1520070, encodeCut: 0.014948 / 0.9)
        case .panalog: return P(slope: 0.324196014, intercept: -0.020278938, logScale: 0.434198361, inputScale: 0.956463747, logBase: 10, logOffset: 0.665276427, inputOffset: 0.040913561, decodeCut: 0.088290045, encodeCut: 0)
        case .djiX5: return P(slope: 1 / (6.025 * 0.9), intercept: -0.0929 / (6.025 * 0.9), logScale: 0.256663, inputScale: 0.9892 * 0.9, logBase: 10, logOffset: 0.584555, inputOffset: 0.0108, decodeCut: 0.14, encodeCut: 0.0078 * 0.9)
        case .protune: return P(slope: 0, intercept: 0, logScale: 876 / 1023, inputScale: 53.39427221, logBase: 113, logOffset: 64 / 1023, inputOffset: 1, decodeCut: 0, encodeCut: 0)
        }
    }
    public static func encodeLegacyToData(_ value: Double, variant: Variant) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }; let q = p(variant)
        let result: Double
        if value >= q.encodeCut {
            result = q.logScale * Foundation.log(value * q.inputScale + q.inputOffset) / Foundation.log(q.logBase) + q.logOffset
        } else if q.slope == 0 {
            // LUTGammaLog's zero-slope branch evaluates the log side at a
            // fixed tiny positive input instead of dividing by zero.
            result = q.logScale * Foundation.log(1e-15 * q.inputScale + q.inputOffset) / Foundation.log(q.logBase) + q.logOffset
        } else {
            result = (value - q.intercept) / q.slope
        }
        guard result.isFinite else { throw NumericError.nonFinite }; return result
    }
    public static func decodeDataToLegacy(_ value: Double, variant: Variant) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }; let q = p(variant)
        let result = value >= q.decodeCut ? (Foundation.pow(q.logBase, (value - q.logOffset) / q.logScale) - q.inputOffset) / q.inputScale : q.slope * value + q.intercept
        guard result.isFinite else { throw NumericError.nonFinite }; return result
    }
}
