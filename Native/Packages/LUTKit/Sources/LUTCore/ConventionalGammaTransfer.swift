import Foundation

/// The legacy LUTGammaGam family used by the old Linear / γ registrations.
///
/// The source implementation stores six parameters.  The twelve built-in
/// registrations in this file are the simple γ1.5…γ2.6 members, whose
/// parameters reduce to a unit low-end slope, zero offset, and a 1e-7
/// branch point.  Values are kept in the old 0.2-grey (legacy) linear domain;
/// the TransformPlan performs the existing legacy↔scene scale separately.
public enum ConventionalGammaTransfer {
    public static func exponent(for transfer: TransferID) throws -> Double {
        switch transfer {
        case .gamma15: return 1.5
        case .gamma16: return 1.6
        case .gamma17: return 1.7
        case .gamma18: return 1.8
        case .gamma19: return 1.9
        case .gamma20: return 2.0
        case .gamma21: return 2.1
        case .gamma22: return 2.2
        case .gamma23: return 2.3
        case .gamma24: return 2.4
        case .gamma25: return 2.5
        case .gamma26: return 2.6
        default: throw TransferError.unsupported
        }
    }

    public static func encodeLegacyToData(_ value: Double, transfer: TransferID) throws -> Double {
        guard value.isFinite else { throw TransferError.nonFinite }
        let exponent = try exponent(for: transfer)
        let legal = encodeLegacyToLegal(value, exponent: exponent)
        return legal * 0.85630498533724 + 0.06256109481916
    }

    public static func decodeDataToLegacy(_ value: Double, transfer: TransferID) throws -> Double {
        guard value.isFinite else { throw TransferError.nonFinite }
        let exponent = try exponent(for: transfer)
        let legal = (value - 0.06256109481916) / 0.85630498533724
        return decodeLegalToLegacy(legal, exponent: exponent)
    }

    private static func encodeLegacyToLegal(_ value: Double, exponent: Double) -> Double {
        let transfer = try! ParameterizedGammaTransfer(
            exponent: exponent, linearSlope: 1, offset: 0,
            linearCut: 0.0000001, encodedCut: 0.0000001)
        return try! transfer.encodeLegacyToLegal(value)
    }

    private static func decodeLegalToLegacy(_ value: Double, exponent: Double) -> Double {
        let transfer = try! ParameterizedGammaTransfer(
            exponent: exponent, linearSlope: 1, offset: 0,
            linearCut: 0.0000001, encodedCut: 0.0000001)
        return try! transfer.decodeLegalToLegacy(value)
    }
}

private enum TransferError: Error {
    case unsupported
    case nonFinite
}
