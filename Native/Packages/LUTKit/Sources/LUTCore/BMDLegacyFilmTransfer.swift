import Foundation

/// Historical LUTGammaLog registrations for the BMD Film family.
///
/// These are scalar legacy identities only. The old registrations do not
/// provide enough evidence for a shared published camera gamut, so the
/// catalog keeps their scalar curves separate from Gen5 and Pocket Film.
public enum BMDLegacyFilmTransfer {
    public enum Variant: String, Sendable {
        case film
        case film4k
        case film46k
    }

    private struct Parameters {
        let slope: Double
        let intercept: Double
        let logScale: Double
        let logInputScale: Double
        let logOffset: Double
        let logInputOffset: Double
        let decodeCut: Double
        let encodeCut: Double
    }

    private static func parameters(for variant: Variant) -> Parameters {
        switch variant {
        case .film:
            return Parameters(
                slope: 0.261115778 * 0.9,
                intercept: -0.024248528 * 0.9,
                logScale: 0.367608577,
                logInputScale: 0.86786483 / 0.9,
                logOffset: 0.644065346,
                logInputOffset: 0.03135747,
                decodeCut: 0.114002127,
                encodeCut: 0.005519226 / 0.9
            )
        case .film4k:
            return Parameters(
                slope: 0.37237694 * 0.9,
                intercept: -0.034580801 * 0.9,
                logScale: 0.582240088,
                logInputScale: 2.617961052 / 0.9,
                logOffset: 0.461883884,
                logInputOffset: 0.231964429,
                decodeCut: 0.10772883,
                encodeCut: 0.005534931 / 0.9
            )
        case .film46k:
            return Parameters(
                slope: 0.195367159 / 0.9,
                intercept: -0.014273567 / 0.9,
                logScale: 0.36274758,
                logInputScale: 1.05345192 * 0.9,
                logOffset: 0.63659829,
                logInputOffset: 0.027616437,
                decodeCut: 0.096214896,
                encodeCut: 0.004523664 * 0.9
            )
        }
    }

    public static func encodeLegacyToData(_ value: Double, variant: Variant) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: variant)
        let result = value >= p.encodeCut
            ? p.logScale * Foundation.log10(value * p.logInputScale + p.logInputOffset) + p.logOffset
            : (value - p.intercept) / p.slope
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }

    public static func decodeDataToLegacy(_ value: Double, variant: Variant) throws -> Double {
        guard value.isFinite else { throw NumericError.nonFinite }
        let p = parameters(for: variant)
        let result = value >= p.decodeCut
            ? (Foundation.pow(10.0, (value - p.logOffset) / p.logScale) - p.logInputOffset) / p.logInputScale
            : p.slope * value + p.intercept
        guard result.isFinite else { throw NumericError.nonFinite }
        return result
    }
}
