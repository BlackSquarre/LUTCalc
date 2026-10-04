import Foundation

public enum FLog2Transfer {
    public static let referenceURL = "https://dl.fujifilm-x.com/technical-data/F-Log2_DataSheet_E_Ver.1.1.pdf"

    // LUTCalc's historical F-Log2 entry used a nine-parameter logarithmic
    // curve with a legacy linear scale. Keep it separate from the published
    // Fujifilm transfer so old projects can be identified without changing
    // the official path.
    private static let legacyLowSlope = 0.12627036
    private static let legacyLowOffset = -0.011725971
    private static let legacyLogSlope = 0.245281
    private static let legacyLogScale = 5.0000004
    private static let legacyLogBase = 10.0
    private static let legacyLogOffset = 0.384316
    private static let legacyLogBias = 0.064829
    private static let legacyDecodeCut = 0.100686685
    private static let legacyEncodeCut = 0.000987778

    public static func encodeSceneToData(_ scene: Double) throws -> Double {
        guard scene.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if scene < 0.000889 {
            result = 8.799461 * scene + 0.092864
        } else {
            result = 0.245281 * log10(5.555556 * scene + 0.064829) + 0.384316
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToScene(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data < 0.100686685370811 {
            result = (data - 0.092864) / 8.799461
        } else {
            result = (pow(10, (data - 0.384316) / 0.245281) - 0.064829) / 5.555556
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func encodeLegacyToData(_ legacyLinear: Double) throws -> Double {
        guard legacyLinear.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if legacyLinear >= legacyEncodeCut {
            result = legacyLogSlope * log10(legacyLogScale * legacyLinear + legacyLogBias) + legacyLogOffset
        } else {
            result = (legacyLinear - legacyLowOffset) / legacyLowSlope
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeLegacyDataToLegacy(_ data: Double) throws -> Double {
        guard data.isFinite else { throw NumericError.nonFinite }
        let result: Double
        if data >= legacyDecodeCut {
            result = (pow(legacyLogBase, (data - legacyLogOffset) / legacyLogSlope) - legacyLogBias) / legacyLogScale
        } else {
            result = legacyLowSlope * data + legacyLowOffset
        }
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
