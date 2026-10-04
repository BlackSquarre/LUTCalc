import Foundation

/// Sony S-Log and S-Log2 analytic curves.
///
/// The published camera curves use a 0.9 reflection adaptation.  The legacy
/// LUTCalc entry points retain the historical linear 0.2 domain and therefore
/// adapt only at the scene boundary in TransformPlan.
public enum SonyLegacyLogTransfer {
    public static let referenceURL =
        "Sony S-Log Technical Summary / S-Log2 Technical Paper; independent implementation: https://github.com/colour-science/colour/blob/ae8d53efdc91bced3fc57aa6a461b3ebc678ddf5/colour/models/rgb/transfer_functions/sony.py"

    private struct Parameters {
        let slope: Double
        let intercept: Double
        let logScale: Double
        let logInputScale: Double
        let base: Double
        let offset: Double
        let logInputOffset: Double
        let decodeCut: Double
        let encodeCut: Double
    }

    // Values frozen by the existing LUTGammaLog registrations.
    private static let sLog = Parameters(
        slope: 0.3241960136, intercept: -0.0286107171,
        logScale: 0.3705223110, logInputScale: 1,
        base: 10, offset: 0.6162444740,
        logInputOffset: 0.0375840000,
        decodeCut: 0.0882900450, encodeCut: 0.000000000000001)
    private static let sLog2 = Parameters(
        slope: 0.330000000129966, intercept: -0.0291229262672453,
        logScale: 0.3705223107287920, logInputScale: 0.7077625570776260,
        base: 10, offset: 0.6162444730868150,
        logInputOffset: 0.0375840001141552,
        decodeCut: 0.0879765396, encodeCut: 0)

    private static func encode(_ value: Double, parameters p: Parameters) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= p.encodeCut
            ? p.logScale * Foundation.log10(value * p.logInputScale + p.logInputOffset) + p.offset
            : (value - p.intercept) / p.slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    private static func decode(_ value: Double, parameters p: Parameters) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let result = value >= p.decodeCut
            ? (Foundation.pow(p.base, (value - p.offset) / p.logScale) - p.logInputOffset) / p.logInputScale
            : p.slope * value + p.intercept
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func encodeSLogToData(_ scene: Double) throws -> Double {
        try encode(scene / 0.9, parameters: sLog)
    }
    public static func decodeDataToSLog(_ data: Double) throws -> Double {
        try decode(data, parameters: sLog) * 0.9
    }
    public static func encodeSLog2ToData(_ scene: Double) throws -> Double {
        try encode(scene / 0.9, parameters: sLog2)
    }
    public static func decodeDataToSLog2(_ data: Double) throws -> Double {
        try decode(data, parameters: sLog2) * 0.9
    }

    public static func encodeSLogLegacyToData(_ value: Double) throws -> Double {
        try encode(value, parameters: sLog)
    }
    public static func decodeDataToSLogLegacy(_ data: Double) throws -> Double {
        try decode(data, parameters: sLog)
    }
    public static func encodeSLog2LegacyToData(_ value: Double) throws -> Double {
        try encode(value, parameters: sLog2)
    }
    public static func decodeDataToSLog2Legacy(_ data: Double) throws -> Double {
        try decode(data, parameters: sLog2)
    }
}
