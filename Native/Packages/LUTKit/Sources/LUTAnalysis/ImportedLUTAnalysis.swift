import Foundation
import CryptoKit
import LUTCore
import LUTFormats

public enum ImportedLUTAnalysisError: Error, Equatable, Sendable {
    case arbitrary3DInverseUnsupported
    case noTransferLUT
    case noShaperLUT
    case nonUniqueTransfer
    case outsideTransferRange
    case transferSolveFailed
    case unsupportedInverseInterpolation
    case invalidMetadata(LUTAnalysisMetadataError)
    case reconstructionRequiresColourLUT
    case reconstructionCountMismatch
    case reconstructionEmptyReference
    case reconstructionNonFiniteReference
    case reconstructionOutsideDomain
    case invalidInverseLimit
}

public enum CombinedShaperColourInverseStatus: Equatable, Sendable {
    case unique
    case multiple
    case noSolution
    case unresolved
    case nonFinite
}

public struct CombinedShaperColourInverseSolution: Equatable, Sendable {
    public let input: RGB64
    public let shapedInput: RGB64
    public let residual: Double

    public init(input: RGB64, shapedInput: RGB64, residual: Double) {
        self.input = input
        self.shapedInput = shapedInput
        self.residual = residual
    }
}

public struct CombinedShaperColourInverseReport: Equatable, Sendable {
    public let status: CombinedShaperColourInverseStatus
    public let solutions: [CombinedShaperColourInverseSolution]
    public let unresolvedColourCellCount: Int
    public let unresolvedShaperChannelCount: Int
    public let isGloballyComplete: Bool

    public init(status: CombinedShaperColourInverseStatus,
                solutions: [CombinedShaperColourInverseSolution],
                unresolvedColourCellCount: Int,
                unresolvedShaperChannelCount: Int,
                isGloballyComplete: Bool) {
        self.status = status
        self.solutions = solutions
        self.unresolvedColourCellCount = unresolvedColourCellCount
        self.unresolvedShaperChannelCount = unresolvedShaperChannelCount
        self.isGloballyComplete = isGloballyComplete
    }
}

/// Residuals from an explicitly requested transfer-then-colour reconstruction.
/// This is a diagnostic of supplied reference pairs, not a proof that an
/// arbitrary 3D LUT has a unique inverse or an inferred camera model.
public struct LUTAnalysisReconstructionReport: Equatable, Sendable {
    public let transferInterpolation: LUTInterpolation
    public let colourInterpolation: LUTInterpolation
    public let sampleCount: Int
    public let residuals: [Double]
    public let maximumAbsoluteResidual: Double
    public let rmsAbsoluteResidual: Double
    public let p99AbsoluteResidual: Double

    public init(transferInterpolation: LUTInterpolation,
                colourInterpolation: LUTInterpolation,
                residuals: [Double]) {
        self.transferInterpolation = transferInterpolation
        self.colourInterpolation = colourInterpolation
        self.sampleCount = residuals.count
        self.residuals = residuals
        maximumAbsoluteResidual = residuals.max() ?? 0
        let sumSquares = residuals.reduce(0) { $0 + $1 * $1 }
        rmsAbsoluteResidual = residuals.isEmpty ? 0 : (sumSquares / Double(residuals.count)).squareRoot()
        if residuals.isEmpty {
            p99AbsoluteResidual = 0
        } else {
            let sorted = residuals.sorted()
            let index = min(sorted.count - 1, max(0, Int(ceil(0.99 * Double(sorted.count))) - 1))
            p99AbsoluteResidual = sorted[index]
        }
    }
}

/// Per-channel result for a 1D transfer inverse probe. A diagnostic preserves
/// non-unique and out-of-range results instead of collapsing them into a
/// single thrown error; it never infers an inverse for a 3D colour LUT.
public struct TransferInverseChannelDiagnostic: Equatable, Sendable {
    public let status: SolveStatus
    public let value: Double?
    public let residual: Double?
    public let bracket: ClosedRange<Double>
    public let iterations: Int
    public let evaluations: Int

    public init(result: SolveResult) {
        status = result.status
        value = result.value
        residual = result.residual
        bracket = result.bracket
        iterations = result.iterations
        evaluations = result.evaluations
    }
}

public struct TransferInverseDiagnostic: Equatable, Sendable {
    public let interpolation: LUTInterpolation
    public let channels: [TransferInverseChannelDiagnostic]

    public init(interpolation: LUTInterpolation,
                channels: [TransferInverseChannelDiagnostic]) {
        self.interpolation = interpolation
        self.channels = channels
    }
}

/// Complete one-dimensional inverse report for one output value. Every
/// channel keeps all roots found across the full cubic domain; a multi-root
/// channel is therefore observable without inferring a 3D inverse.
public struct TransferInverseRootDiagnostic: Equatable, Sendable {
    public let status: SolveStatus
    public let roots: [TransferInverseChannelDiagnostic]
    /// Intervals on which the cubic equals the requested value everywhere.
    public let nonUniqueBrackets: [ClosedRange<Double>]

    public init(status: SolveStatus, roots: [TransferInverseChannelDiagnostic],
                nonUniqueBrackets: [ClosedRange<Double>] = []) {
        self.status = status
        self.roots = roots
        self.nonUniqueBrackets = nonUniqueBrackets
    }
}

public struct TransferInverseGlobalDiagnostic: Equatable, Sendable {
    public let interpolation: LUTInterpolation
    public let channels: [TransferInverseRootDiagnostic]

    public init(interpolation: LUTInterpolation,
                channels: [TransferInverseRootDiagnostic]) {
        self.interpolation = interpolation
        self.channels = channels
    }
}

public enum ColourLUTInverseAvailability: Equatable, Sendable {
    case notPresent
    case requiresExplicitModel
}

/// Metadata carried into analysis without changing the sampled LUT values.
/// The transfer and colour sections stay separate; unknown producer values
/// remain represented by the format-layer semantic enums.
public struct ImportedLUTMetadataAnalysis: Equatable, Sendable {
    public let transfer: LUTAnalysisMetadataSemantics
    public let colour: LUTAnalysisMetadataSemantics?
    public let quantization: LUTAnalysisQuantizationSemantics

    public init(transfer: LUTAnalysisMetadataSemantics,
                colour: LUTAnalysisMetadataSemantics?,
                quantization: LUTAnalysisQuantizationSemantics) {
        self.transfer = transfer
        self.colour = colour
        self.quantization = quantization
    }

    /// Synthetic callers may provide an empty analysis wrapper only to select
    /// a transfer section. It carries no source identity and must retain the
    /// historical direct-LUT fingerprint. Real `.lacube`/`.labin` sources
    /// always carry a known quantization kind and therefore participate.
    public var contributesToIdentity: Bool {
        let empty = LUTAnalysisMetadataSemantics(inputRange: .unspecified,
                                                 inputBounds: 0...1,
                                                 interpolation: .unspecified,
                                                 baseISO: nil)
        return transfer != empty || colour != nil || quantization.kind != .unknown
    }
}

public struct IndependentChannelAnalysis: Equatable, Sendable {
    public let red: MonotonicCurve1DAnalysis
    public let green: MonotonicCurve1DAnalysis
    public let blue: MonotonicCurve1DAnalysis

    public var isInvertibleBySingleValue: Bool {
        red.isInvertibleBySingleValue && green.isInvertibleBySingleValue
            && blue.isInvertibleBySingleValue
    }
}

/// Only structural analysis of imported samples. A stored input matrix or a
/// visually affine LUT is not evidence of a globally invertible 3D model.
public struct ImportedLUTAnalysisReport: Sendable {
    public let transfer: IndependentChannelAnalysis?
    public let shaper: IndependentChannelAnalysis?
    public let metadata: ImportedLUTMetadataAnalysis?
    public let hasColourLUT: Bool
    public let colourInverse: ColourLUTInverseAvailability

    public func inverseColourLUT(_ output: RGB64) throws -> RGB64 {
        throw ImportedLUTAnalysisError.arbitrary3DInverseUnsupported
    }

    /// Applies an explicitly supplied affine model to the colour section.
    /// The model is owned by the caller; no affine transform is inferred from
    /// sampled LUT nodes. Arbitrary colour LUTs remain unsupported above.
    public func inverseColourLUT(
        _ output: RGB64,
        using model: KnownAffine3DTransform,
        inputDomain: LUTDomain? = nil,
        outputDomain: LUTDomain? = nil,
        tolerance: Double = 2e-12
    ) throws -> RGB64 {
        guard hasColourLUT else {
            throw ImportedLUTAnalysisError.arbitrary3DInverseUnsupported
        }
        return try model.inverse(output,
                                 inputDomain: inputDomain,
                                 outputDomain: outputDomain,
                                 tolerance: tolerance)
    }
}

/// A frozen, explicit inverse plan for the strictly single-valued 1D cubic
/// transfer subset.  It is deliberately separate from the arbitrary 3D LUT
/// path: construction validates the complete cubic curve once, while each
/// generated node only performs the three scalar inversions.
public struct ImportedLUTInversePlan: Sendable {
    public let interpolation: LUTInterpolation
    /// Preserves the source file semantics that selected this transfer. The
    /// metadata is provenance and request identity; it never changes the
    /// sampled Double values or interpolation implementation.
    public let metadata: ImportedLUTMetadataAnalysis?
    /// Binds the effective transfer selected from the analysis file or LUT.
    /// Titles and provenance do not affect the frozen numerical operation.
    public let contentFingerprint: String
    private let red: LegacyCubicCurve1D
    private let green: LegacyCubicCurve1D
    private let blue: LegacyCubicCurve1D

    public init(lut: CubeLUT, analysisFile: LUTAnalysisFile?,
                interpolation: LUTInterpolation) throws {
        guard interpolation == .tricubicLegacyV1 else {
            throw ImportedLUTAnalysisError.unsupportedInverseInterpolation
        }
        guard let transferLUT = analysisFile?.transferLUT ?? (lut.dimension == .one ? lut : nil),
              transferLUT.dimension == .one, transferLUT.shaper == nil else {
            throw ImportedLUTAnalysisError.noTransferLUT
        }
        let metadata: ImportedLUTMetadataAnalysis?
        if let analysisFile {
            do {
                metadata = ImportedLUTMetadataAnalysis(
                    transfer: try analysisFile.transferMetadata.semantics(),
                    colour: try analysisFile.colourMetadata.map { try $0.semantics() },
                    quantization: analysisFile.quantizationSemantics)
            } catch let error as LUTAnalysisMetadataError {
                throw ImportedLUTAnalysisError.invalidMetadata(error)
            }
        } else {
            metadata = nil
        }
        let curves = try (0..<3).map { channel in
            try LegacyCubicCurve1D(
                values: transferLUT.samples.map { $0[channel] },
                lower: transferLUT.domain.min[channel],
                upper: transferLUT.domain.max[channel])
        }
        guard curves.allSatisfy(\.isGloballySingleValued) else {
            throw ImportedLUTAnalysisError.nonUniqueTransfer
        }
        let identityMetadata = metadata?.contributesToIdentity == true ? metadata : nil
        self.interpolation = interpolation
        self.metadata = identityMetadata
        self.contentFingerprint = Self.identity(transferLUT, interpolation: interpolation,
                                                metadata: identityMetadata)
        self.red = curves[0]
        self.green = curves[1]
        self.blue = curves[2]
    }

    private static func identity(_ lut: CubeLUT, interpolation: LUTInterpolation,
                                 metadata: ImportedLUTMetadataAnalysis?) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("native.input-transfer-inverse-content.v1\0".utf8))
        hasher.update(data: Data((interpolation.rawValue + "\0").utf8))
        func update(_ bits: UInt64) {
            var value = bits.littleEndian
            withUnsafeBytes(of: &value) { hasher.update(bufferPointer: $0) }
        }
        update(UInt64(lut.size))
        for value in [lut.domain.min, lut.domain.max] {
            for channel in 0..<3 { update(value[channel].bitPattern) }
        }
        for sample in lut.samples {
            for channel in 0..<3 { update(sample[channel].bitPattern) }
        }
        func update(_ text: String) {
            let data = Data(text.utf8)
            update(UInt64(data.count))
            hasher.update(data: data)
        }
        func update(_ semantics: LUTAnalysisMetadataSemantics) {
            update(String(describing: semantics.inputRange))
            update(semantics.inputBounds.lowerBound.bitPattern)
            update(semantics.inputBounds.upperBound.bitPattern)
            update(String(describing: semantics.interpolation))
            if let baseISO = semantics.baseISO { update(UInt64(bitPattern: Int64(baseISO))) }
            else { update(UInt64.max) }
        }
        if let metadata {
            update("metadata-v1")
            update(metadata.transfer)
            if let colour = metadata.colour {
                update("colour")
                update(colour)
            } else {
                update("no-colour")
            }
            update(String(describing: metadata.quantization.kind))
            update(metadata.quantization.sampleScale?.bitPattern ?? UInt64.max)
            update(metadata.quantization.matrixScale?.bitPattern ?? UInt64.max)
            update(metadata.quantization.lossySentinel.map { UInt64(bitPattern: Int64($0)) } ?? UInt64.max)
            update(metadata.quantization.byteOrder.map(String.init(describing:)) ?? "no-byte-order")
            update(metadata.quantization.rounding.map(String.init(describing:)) ?? "no-rounding")
        } else {
            update("no-metadata")
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public func apply(_ output: RGB64) throws -> RGB64 {
        func solve(_ curve: LegacyCubicCurve1D, _ target: Double) throws -> Double {
            let result = curve.inverse(target)
            guard result.status == .converged, let value = result.value else {
                switch result.status {
                case .notBracketed: throw ImportedLUTAnalysisError.outsideTransferRange
                case .nonUnique: throw ImportedLUTAnalysisError.nonUniqueTransfer
                case .nonFinite: throw ImportedLUTAnalysisError.transferSolveFailed
                default: throw ImportedLUTAnalysisError.transferSolveFailed
                }
            }
            return value
        }
        return try RGB64(solve(red, output.r), solve(green, output.g), solve(blue, output.b))
    }
}

public enum ImportedLUTAnalyzer {
    /// Reconstructs explicitly supplied reference pairs through the two
    /// sections of an analysis file. No model is inferred from samples and no
    /// inverse is attempted; the caller chooses both interpolation rules.
    public static func reconstructionReport(
        lut: CubeLUT,
        analysisFile: LUTAnalysisFile?,
        inputs: [RGB64],
        expectedOutputs: [RGB64],
        transferInterpolation: LUTInterpolation,
        colourInterpolation: LUTInterpolation
    ) throws -> LUTAnalysisReconstructionReport {
        guard let analysisFile, let colourLUT = analysisFile.colourLUT,
              colourLUT.dimension == .three else {
            throw ImportedLUTAnalysisError.reconstructionRequiresColourLUT
        }
        guard inputs.count == expectedOutputs.count else {
            throw ImportedLUTAnalysisError.reconstructionCountMismatch
        }
        guard !inputs.isEmpty else {
            throw ImportedLUTAnalysisError.reconstructionEmptyReference
        }
        guard inputs.allSatisfy(Self.isFinite) && expectedOutputs.allSatisfy(Self.isFinite) else {
            throw ImportedLUTAnalysisError.reconstructionNonFiniteReference
        }
        do {
            _ = try analysisFile.transferMetadata.semantics()
            if let colourMetadata = analysisFile.colourMetadata {
                _ = try colourMetadata.semantics()
            }
        } catch let error as LUTAnalysisMetadataError {
            throw ImportedLUTAnalysisError.invalidMetadata(error)
        }
        let transfer = analysisFile.transferLUT
        guard transfer.dimension == .one else {
            throw ImportedLUTAnalysisError.noTransferLUT
        }
        let transferSampler = try transfer.preparedSampler(interpolation: transferInterpolation)
        let colourSampler = try colourLUT.preparedSampler(interpolation: colourInterpolation)
        var residuals: [Double] = []
        residuals.reserveCapacity(inputs.count)
        for index in inputs.indices {
            let shaped: RGB64
            let reconstructed: RGB64
            do {
                shaped = try transferSampler.sample(inputs[index], outside: .reject)
                reconstructed = try colourSampler.sample(shaped, outside: .reject)
            } catch VolumeError.outsideDomain {
                throw ImportedLUTAnalysisError.reconstructionOutsideDomain
            }
            let expected = expectedOutputs[index]
            let residual = max(abs(reconstructed.r - expected.r),
                               abs(reconstructed.g - expected.g),
                               abs(reconstructed.b - expected.b))
            guard residual.isFinite else {
                throw ImportedLUTAnalysisError.reconstructionNonFiniteReference
            }
            residuals.append(residual)
        }
        return LUTAnalysisReconstructionReport(
            transferInterpolation: transferInterpolation,
            colourInterpolation: colourInterpolation,
            residuals: residuals)
    }

    private static func isFinite(_ value: RGB64) -> Bool {
        value.r.isFinite && value.g.isFinite && value.b.isFinite
    }

    private static func sameInput(_ left: RGB64, _ right: RGB64) -> Bool {
        let scale = max(1, abs(left.r), abs(left.g), abs(left.b),
                        abs(right.r), abs(right.g), abs(right.b))
        let limit = 64 * Double.ulpOfOne * scale
        return abs(left.r - right.r) <= limit
            && abs(left.g - right.g) <= limit
            && abs(left.b - right.b) <= limit
    }

    public static func analyze(lut: CubeLUT,
                               analysisFile: LUTAnalysisFile?) throws -> ImportedLUTAnalysisReport {
        let transferLUT = analysisFile?.transferLUT ?? (lut.dimension == .one ? lut : nil)
        let transfer = try transferLUT.map { try channels($0.samples, domain: $0.domain) }
        let shaper = try lut.shaper.map { try channels($0.samples, domain: $0.domain) }
        let hasColour = lut.dimension == .three || analysisFile?.colourLUT != nil
        let metadata: ImportedLUTMetadataAnalysis?
        if let analysisFile {
            do {
                metadata = ImportedLUTMetadataAnalysis(
                    transfer: try analysisFile.transferMetadata.semantics(),
                    colour: try analysisFile.colourMetadata.map { try $0.semantics() },
                    quantization: analysisFile.quantizationSemantics)
            } catch let error as LUTAnalysisMetadataError {
                throw ImportedLUTAnalysisError.invalidMetadata(error)
            }
        } else {
            metadata = nil
        }
        return ImportedLUTAnalysisReport(transfer: transfer, shaper: shaper,
                                         metadata: metadata,
                                         hasColourLUT: hasColour,
                                         colourInverse: hasColour ? .requiresExplicitModel : .notPresent)
    }

    public static func inverseTransfer(lut: CubeLUT, analysisFile: LUTAnalysisFile?,
                                       output: RGB64,
                                       interpolation: LUTInterpolation = .trilinear) throws -> RGB64 {
        guard let transferLUT = analysisFile?.transferLUT ?? (lut.dimension == .one ? lut : nil) else {
            throw ImportedLUTAnalysisError.noTransferLUT
        }
        let report = try channels(transferLUT.samples, domain: transferLUT.domain)
        guard interpolation == .tricubicLegacyV1 || report.isInvertibleBySingleValue else {
            throw ImportedLUTAnalysisError.nonUniqueTransfer
        }
        func inverse(channel: Int) throws -> Double {
            let values = transferLUT.samples.map { $0[channel] }
            let domain = transferLUT.domain.min[channel]...transferLUT.domain.max[channel]
            if interpolation == .tricubicLegacyV1 {
                let curve = try LegacyCubicCurve1D(values: values,
                                                   lower: domain.lowerBound,
                                                   upper: domain.upperBound)
                return try mapInverseResult(curve.inverse(output[channel]))
            }
            let curve = try MonotonicCurve1D(values: values, domain: domain)
            return try mapInverseResult(curve.inverse(output[channel]))
        }
        func mapInverseResult(_ result: SolveResult) throws -> Double {
            switch result.status {
            case .converged:
                guard let value = result.value else {
                    throw ImportedLUTAnalysisError.transferSolveFailed
                }
                return value
            case .notBracketed:
                throw ImportedLUTAnalysisError.outsideTransferRange
            case .nonUnique:
                throw ImportedLUTAnalysisError.nonUniqueTransfer
            case .nonFinite, .maxIterations, .cancelled, .evaluationFailed:
                throw ImportedLUTAnalysisError.transferSolveFailed
            }
        }
        return try RGB64(inverse(channel: 0), inverse(channel: 1), inverse(channel: 2))
    }

    /// Reports each independent transfer channel without discarding partial
    /// results. This is intentionally limited to a 1D transfer LUT.
    public static func diagnoseTransferInverse(
        lut: CubeLUT,
        analysisFile: LUTAnalysisFile?,
        output: RGB64,
        interpolation: LUTInterpolation = .trilinear
    ) throws -> TransferInverseDiagnostic {
        guard let transferLUT = analysisFile?.transferLUT ?? (lut.dimension == .one ? lut : nil) else {
            throw ImportedLUTAnalysisError.noTransferLUT
        }
        return try diagnoseIndependentInverse(samples: transferLUT.samples,
                                              domain: transferLUT.domain,
                                              output: output,
                                              interpolation: interpolation)
    }

    /// Exhaustively diagnoses the piecewise-affine inverse induced by the
    /// selected tetrahedral partition. Other interpolation rules and CUBE
    /// shapers remain explicit unsupported cases; this does not infer a
    /// different interpolation model or repair the source LUT.
    public static func diagnoseTetrahedralColourInverse(
        lut: CubeLUT,
        output: RGB64,
        interpolation: LUTInterpolation = .tetrahedral,
        tolerance: Double = 2e-12,
        maxCondition: Double = 1e8
    ) throws -> Tetrahedral3DInverseReport {
        guard interpolation == .tetrahedral else {
            throw ImportedLUTAnalysisError.unsupportedInverseInterpolation
        }
        return try Tetrahedral3DInverse.analyze(output, in: lut,
                                                tolerance: tolerance,
                                                maxCondition: maxCondition)
    }

    /// Conservatively diagnoses the multilinear inverse of a colour LUT.
    /// Singular cells remain unresolved; no arbitrary 3D model is inferred.
    public static func diagnoseTrilinearColourInverse(
        lut: CubeLUT,
        output: RGB64,
        interpolation: LUTInterpolation = .trilinear,
        tolerance: Double = 2e-12,
        maxBoxes: Int = 100_000
    ) throws -> Trilinear3DInverseReport {
        guard interpolation == .trilinear else {
            throw ImportedLUTAnalysisError.unsupportedInverseInterpolation
        }
        return try Trilinear3DInverse.analyze(output, in: lut,
                                               tolerance: tolerance,
                                               maxBoxes: maxBoxes)
    }

    /// Conservatively diagnoses the legacy tensor-product cubic inverse. The
    /// result is accepted only after replaying the same production sampler;
    /// unresolved cells remain explicit instead of being treated as no root.
    public static func diagnoseTricubicColourInverse(
        lut: CubeLUT,
        output: RGB64,
        interpolation: LUTInterpolation = .tricubicLegacyV1,
        tolerance: Double = 2e-12,
        maxCells: Int = 100_000
    ) throws -> Tricubic3DInverseReport {
        guard interpolation == .tricubicLegacyV1 else {
            throw ImportedLUTAnalysisError.unsupportedInverseInterpolation
        }
        return try Tricubic3DInverse.analyze(output, in: lut,
                                              tolerance: tolerance,
                                              maxCells: maxCells)
    }

    /// Diagnoses the explicit composition `shaper -> colour LUT`. The colour
    /// section is inverted first, then every certified scalar shaper root is
    /// combined and replayed through the complete production sampler. This is
    /// a diagnostic only: unresolved colour cells or shaper branches remain
    /// visible and no root is inferred from an arbitrary LUT.
    public static func diagnoseCombinedShaperColourInverse(
        lut: CubeLUT,
        output: RGB64,
        colourInterpolation: LUTInterpolation = .tricubicLegacyV1,
        shaperInterpolation: LUTInterpolation = .tricubicLegacyV1,
        tolerance: Double = 2e-12,
        maxCells: Int = 100_000,
        maxSolutions: Int = 100_000
    ) throws -> CombinedShaperColourInverseReport {
        guard lut.dimension == .three, lut.shaper != nil else {
            throw ImportedLUTAnalysisError.noShaperLUT
        }
        guard tolerance.isFinite, tolerance >= 0,
              maxCells > 0, maxSolutions > 0 else {
            throw ImportedLUTAnalysisError.invalidInverseLimit
        }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            return CombinedShaperColourInverseReport(status: .nonFinite,
                                                      solutions: [],
                                                      unresolvedColourCellCount: 0,
                                                      unresolvedShaperChannelCount: 0,
                                                      isGloballyComplete: false)
        }
        guard colourInterpolation == .trilinear || colourInterpolation == .tetrahedral
                || colourInterpolation == .tricubicLegacyV1,
              shaperInterpolation == .trilinear || shaperInterpolation == .tricubicLegacyV1 else {
            throw ImportedLUTAnalysisError.unsupportedInverseInterpolation
        }

        // Invert the colour section without passing the shaper twice. The
        // original LUT remains untouched for the final production replay.
        let colourLUT = try CubeLUT(dimension: .three, size: lut.size,
                                    domain: lut.domain, samples: lut.samples)
        let colourStatus: CombinedShaperColourInverseStatus
        let colourSolutions: [(RGB64, Double)]
        let unresolvedColour: Int
        switch colourInterpolation {
        case .trilinear:
            let report = try Trilinear3DInverse.analyze(output, in: colourLUT,
                                                        tolerance: tolerance,
                                                        maxBoxes: maxCells)
            colourStatus = combinedStatus(report.status)
            colourSolutions = report.solutions.map { ($0.input, $0.residual) }
            unresolvedColour = report.unresolvedBoxCount
        case .tetrahedral:
            let report = try Tetrahedral3DInverse.analyze(output, in: colourLUT,
                                                          tolerance: tolerance,
                                                          maxTetrahedra: maxCells)
            colourStatus = combinedStatus(report.status)
            colourSolutions = report.solutions.map { ($0.input, $0.residual) }
            unresolvedColour = report.unresolvedTetrahedronCount
        case .tricubicLegacyV1:
            let report = try Tricubic3DInverse.analyze(output, in: colourLUT,
                                                       tolerance: tolerance,
                                                       maxCells: maxCells)
            colourStatus = combinedStatus(report.status)
            colourSolutions = report.solutions.map { ($0.input, $0.residual) }
            unresolvedColour = report.unresolvedCellCount
        }

        let shaper = lut.shaper!
        let curves = try (0..<3).map { channel in
            try LegacyCubicCurve1D(values: shaper.samples.map { $0[channel] },
                                    lower: shaper.domain.min[channel],
                                    upper: shaper.domain.max[channel])
        }
        var unresolvedShaper = 0
        var solutions: [CombinedShaperColourInverseSolution] = []
        for (shapedInput, _) in colourSolutions {
            try Task.checkCancellation()
            let roots = try curves.enumerated().map { index, curve in
                try Task.checkCancellation()
                return try scalarShaperRoots(curve: curve, target: shapedInput[index],
                                             interpolation: shaperInterpolation,
                                             tolerance: tolerance,
                                             unresolved: &unresolvedShaper)
            }
            guard roots.allSatisfy({ !$0.isEmpty }) else { continue }
            for r in roots[0] {
                try Task.checkCancellation()
                for g in roots[1] {
                    try Task.checkCancellation()
                    for b in roots[2] {
                        try Task.checkCancellation()
                        let input = try RGB64(r, g, b)
                        guard let replay = try? lut.sample(input,
                                                          interpolation: colourInterpolation,
                                                          outside: .reject) else { continue }
                        let residual = max(abs(replay.r - output.r),
                                           abs(replay.g - output.g),
                                           abs(replay.b - output.b))
                        let scale = max(1, abs(output.r), abs(output.g), abs(output.b))
                        guard residual.isFinite, residual <= tolerance * scale else { continue }
                        if !solutions.contains(where: { sameInput($0.input, input) }) {
                            if solutions.count >= maxSolutions {
                                throw ImportedLUTAnalysisError.invalidInverseLimit
                            }
                            solutions.append(CombinedShaperColourInverseSolution(
                                input: input, shapedInput: shapedInput, residual: residual))
                        }
                    }
                }
            }
        }
        solutions.sort {
            if $0.input.r != $1.input.r { return $0.input.r < $1.input.r }
            if $0.input.g != $1.input.g { return $0.input.g < $1.input.g }
            return $0.input.b < $1.input.b
        }
        let status: CombinedShaperColourInverseStatus
        if colourStatus == .nonFinite { status = .nonFinite }
        else if unresolvedColour > 0 || unresolvedShaper > 0 { status = .unresolved }
        else if solutions.count > 1 { status = .multiple }
        else if solutions.count == 1 { status = .unique }
        else { status = .noSolution }
        return CombinedShaperColourInverseReport(status: status,
                                                 solutions: solutions,
                                                 unresolvedColourCellCount: unresolvedColour,
                                                 unresolvedShaperChannelCount: unresolvedShaper,
                                                 isGloballyComplete: unresolvedColour == 0 && unresolvedShaper == 0)
    }

    private static func combinedStatus(_ status: Tricubic3DInverseStatus)
        -> CombinedShaperColourInverseStatus {
        switch status {
        case .unique: return .unique
        case .multiple: return .multiple
        case .noSolution: return .noSolution
        case .unresolved: return .unresolved
        case .nonFinite: return .nonFinite
        }
    }

    private static func combinedStatus(_ status: Trilinear3DInverseStatus)
        -> CombinedShaperColourInverseStatus {
        switch status {
        case .unique: return .unique
        case .multiple: return .multiple
        case .noSolution: return .noSolution
        case .unresolved: return .unresolved
        case .nonFinite: return .nonFinite
        }
    }

    private static func combinedStatus(_ status: Tetrahedral3DInverseStatus)
        -> CombinedShaperColourInverseStatus {
        switch status {
        case .unique: return .unique
        case .multiple: return .multiple
        case .noSolution: return .noSolution
        case .unresolved: return .unresolved
        case .nonFinite: return .nonFinite
        }
    }

    private static func scalarShaperRoots(curve: LegacyCubicCurve1D,
                                          target: Double,
                                          interpolation: LUTInterpolation,
                                          tolerance: Double,
                                          unresolved: inout Int) throws -> [Double] {
        if interpolation == .tricubicLegacyV1 {
            let results = curve.allInverseRoots(target,
                                                tolerance: SolveTolerance(
                                                    fAbsolute: tolerance,
                                                    fRelative: tolerance))
            let roots = results.compactMap { $0.status == .converged ? $0.value : nil }
            if results.contains(where: { $0.status == .nonUnique }) { unresolved += 1 }
            if roots.isEmpty && results.contains(where: {
                $0.status != .notBracketed && $0.status != .converged
            }) { unresolved += 1 }
            return roots
        }
        do {
            let monotonic = try MonotonicCurve1D(values: curve.values,
                                                  domain: curve.lower...curve.upper)
            let result = monotonic.inverse(target)
            guard result.status == .converged, let value = result.value else {
                if result.status != .notBracketed { unresolved += 1 }
                return []
            }
            return [value]
        } catch Curve1DError.notMonotonic {
            unresolved += 1
            return []
        }
    }

    /// Reports each independent 1D shaper channel without traversing the
    /// following 3D colour volume. The report has the same explicit failure
    /// semantics as `diagnoseTransferInverse`.
    public static func diagnoseShaperInverse(
        lut: CubeLUT,
        output: RGB64,
        interpolation: LUTInterpolation = .trilinear
    ) throws -> TransferInverseDiagnostic {
        guard let shaper = lut.shaper else { throw ImportedLUTAnalysisError.noShaperLUT }
        return try diagnoseIndependentInverse(samples: shaper.samples,
                                              domain: shaper.domain,
                                              output: output,
                                              interpolation: interpolation)
    }

    /// Reports every root of each independent 1D transfer channel. This is
    /// intentionally limited to transfer/shaper curves and never traverses a
    /// 3D colour LUT.
    public static func diagnoseTransferInverseRoots(
        lut: CubeLUT,
        analysisFile: LUTAnalysisFile?,
        output: RGB64,
        interpolation: LUTInterpolation = .tricubicLegacyV1
    ) throws -> TransferInverseGlobalDiagnostic {
        guard let transferLUT = analysisFile?.transferLUT ?? (lut.dimension == .one ? lut : nil) else {
            throw ImportedLUTAnalysisError.noTransferLUT
        }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            let channels = (0..<3).map { _ in
                TransferInverseRootDiagnostic(status: .nonFinite, roots: [])
            }
            return TransferInverseGlobalDiagnostic(interpolation: interpolation, channels: channels)
        }
        guard interpolation == .tricubicLegacyV1 else {
            return try diagnoseTransferInverse(lut: lut, analysisFile: analysisFile,
                                               output: output, interpolation: interpolation)
                .channels.map { channel in
                    TransferInverseRootDiagnostic(status: channel.status, roots: [channel])
                }
                .withGlobal(interpolation: interpolation)
        }
        let channels = try (0..<3).map { channel -> TransferInverseRootDiagnostic in
            let values = transferLUT.samples.map { $0[channel] }
            let domain = transferLUT.domain.min[channel]...transferLUT.domain.max[channel]
            let curve = try LegacyCubicCurve1D(values: values,
                                                lower: domain.lowerBound,
                                                upper: domain.upperBound)
            let results = curve.allInverseRoots(output[channel])
            let roots = results.filter { $0.status == .converged }
                .map(TransferInverseChannelDiagnostic.init)
            let nonUniqueBrackets = results.filter { $0.status == .nonUnique }.map(\.bracket)
            let status: SolveStatus = roots.count > 1 || !nonUniqueBrackets.isEmpty ? .nonUnique
                : (roots.isEmpty ? (results.first?.status ?? .notBracketed) : .converged)
            return TransferInverseRootDiagnostic(status: status, roots: roots,
                                                 nonUniqueBrackets: nonUniqueBrackets)
        }
        return TransferInverseGlobalDiagnostic(interpolation: interpolation, channels: channels)
    }

    private static func diagnoseIndependentInverse(
        samples: [RGB64],
        domain: LUTDomain,
        output: RGB64,
        interpolation: LUTInterpolation
    ) throws -> TransferInverseDiagnostic {
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            let channels = (0..<3).map { channel in
                let bracket = domain.min[channel]...domain.max[channel]
                return TransferInverseChannelDiagnostic(result: SolveResult(
                    status: .nonFinite, value: nil, residual: nil,
                    bracket: bracket, iterations: 0, evaluations: 0))
            }
            return TransferInverseDiagnostic(interpolation: interpolation, channels: channels)
        }

        var channels: [TransferInverseChannelDiagnostic] = []
        channels.reserveCapacity(3)
        for channel in 0..<3 {
            let values = samples.map { $0[channel] }
            let channelDomain = domain.min[channel]...domain.max[channel]
            let target = output[channel]
            let result: SolveResult
            if interpolation == .tricubicLegacyV1 {
                let curve = try LegacyCubicCurve1D(values: values,
                                                   lower: channelDomain.lowerBound,
                                                   upper: channelDomain.upperBound)
                result = curve.inverse(target)
            } else {
                do {
                    let curve = try MonotonicCurve1D(values: values, domain: channelDomain)
                    result = curve.inverse(target)
                } catch Curve1DError.notMonotonic {
                    result = SolveResult(status: .nonUnique, value: nil, residual: nil,
                                         bracket: channelDomain, iterations: 0, evaluations: 0)
                }
            }
            channels.append(TransferInverseChannelDiagnostic(result: result))
        }
        return TransferInverseDiagnostic(interpolation: interpolation, channels: channels)
    }

    /// Inverts only the independent 1D shaper preceding a 3D LUT. The colour
    /// volume is intentionally not traversed or inferred to be invertible.
    public static func inverseShaper(lut: CubeLUT, output: RGB64,
                                     interpolation: LUTInterpolation = .trilinear) throws -> RGB64 {
        guard let shaper = lut.shaper else { throw ImportedLUTAnalysisError.noShaperLUT }
        let report = try channels(shaper.samples, domain: shaper.domain)
        guard interpolation == .tricubicLegacyV1 || report.isInvertibleBySingleValue else {
            throw ImportedLUTAnalysisError.nonUniqueTransfer
        }
        func inverse(channel: Int) throws -> Double {
            let values = shaper.samples.map { $0[channel] }
            let domain = shaper.domain.min[channel]...shaper.domain.max[channel]
            if interpolation == .tricubicLegacyV1 {
                let curve = try LegacyCubicCurve1D(values: values,
                                                   lower: domain.lowerBound,
                                                   upper: domain.upperBound)
                return try mapInverseResult(curve.inverse(output[channel]))
            }
            let curve = try MonotonicCurve1D(values: values, domain: domain)
            return try mapInverseResult(curve.inverse(output[channel]))
        }
        func mapInverseResult(_ result: SolveResult) throws -> Double {
            switch result.status {
            case .converged:
                guard let value = result.value else { throw ImportedLUTAnalysisError.transferSolveFailed }
                return value
            case .notBracketed: throw ImportedLUTAnalysisError.outsideTransferRange
            case .nonUnique: throw ImportedLUTAnalysisError.nonUniqueTransfer
            case .nonFinite, .maxIterations, .cancelled, .evaluationFailed:
                throw ImportedLUTAnalysisError.transferSolveFailed
            }
        }
        return try RGB64(inverse(channel: 0), inverse(channel: 1), inverse(channel: 2))
    }

    private static func channels(_ samples: [RGB64], domain: LUTDomain) throws -> IndependentChannelAnalysis {
        let red = try MonotonicCurve1DAnalyzer.analyze(values: samples.map(\.r),
                                                        domain: domain.min.r...domain.max.r)
        let green = try MonotonicCurve1DAnalyzer.analyze(values: samples.map(\.g),
                                                          domain: domain.min.g...domain.max.g)
        let blue = try MonotonicCurve1DAnalyzer.analyze(values: samples.map(\.b),
                                                         domain: domain.min.b...domain.max.b)
        return IndependentChannelAnalysis(red: red, green: green, blue: blue)
    }
}

private extension Array where Element == TransferInverseRootDiagnostic {
    func withGlobal(interpolation: LUTInterpolation) -> TransferInverseGlobalDiagnostic {
        TransferInverseGlobalDiagnostic(interpolation: interpolation, channels: self)
    }
}
