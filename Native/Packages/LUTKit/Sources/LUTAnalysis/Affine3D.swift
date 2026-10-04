import Foundation
import CryptoKit
import LUTCore

public enum Affine3DModelStatus: Equatable, Sendable {
    case uniquelyInvertible
    case illConditioned
    case nonUnique
    case invalidTolerance
}

/// Structural diagnostics for a caller-supplied affine colour model.
/// This does not infer a model from LUT samples. It only reports whether the
/// supplied matrix has a numerically usable, unique inverse under the chosen
/// condition threshold.
public struct Affine3DModelAnalysis: Equatable, Sendable {
    public let status: Affine3DModelStatus
    public let conditionNumber: Double?
    public let identityResidual: Double?

    public var hasUniqueInverse: Bool { status == .uniquelyInvertible }

    public static func analyze(matrix: Matrix3x3,
                               maxCondition: Double = 1e8) -> Affine3DModelAnalysis {
        guard maxCondition.isFinite, maxCondition > 0 else {
            return Affine3DModelAnalysis(status: .invalidTolerance,
                                          conditionNumber: nil,
                                          identityResidual: nil)
        }
        let inverse: Matrix3x3
        do {
            // Use an effectively unbounded finite threshold to measure the
            // condition before applying the caller's acceptance threshold.
            inverse = try matrix.inverted(maxCondition: Double.greatestFiniteMagnitude)
        } catch MatrixError.singular {
            return Affine3DModelAnalysis(status: .nonUnique,
                                          conditionNumber: nil,
                                          identityResidual: nil)
        } catch MatrixError.illConditioned {
            return Affine3DModelAnalysis(status: .illConditioned,
                                          conditionNumber: nil,
                                          identityResidual: nil)
        } catch MatrixError.excessiveResidual {
            return Affine3DModelAnalysis(status: .illConditioned,
                                          conditionNumber: nil,
                                          identityResidual: nil)
        } catch {
            return Affine3DModelAnalysis(status: .nonUnique,
                                          conditionNumber: nil,
                                          identityResidual: nil)
        }
        let condition = matrix.normInfinity * inverse.normInfinity
        let product = (try? matrix.multiplied(by: inverse))
        let residual = product.map { result in
            (0..<3).map { row in
                (0..<3).reduce(0.0) { sum, column in
                    sum + abs(result[row, column] - (row == column ? 1 : 0))
                }
            }.max() ?? Double.infinity
        } ?? Double.infinity
        guard condition.isFinite, residual.isFinite else {
            return Affine3DModelAnalysis(status: .illConditioned,
                                          conditionNumber: condition.isFinite ? condition : nil,
                                          identityResidual: residual.isFinite ? residual : nil)
        }
        let status: Affine3DModelStatus = condition <= maxCondition ? .uniquelyInvertible : .illConditioned
        return Affine3DModelAnalysis(status: status,
                                     conditionNumber: condition,
                                     identityResidual: residual)
    }

    private init(status: Affine3DModelStatus,
                 conditionNumber: Double?,
                 identityResidual: Double?) {
        self.status = status
        self.conditionNumber = conditionNumber
        self.identityResidual = identityResidual
    }
}

public enum Affine3DError: Error, Equatable, Sendable {
    case nonFinite
    case outsideDomain
    case invalidTolerance
    case excessiveResidual
}

/// An explicitly supplied affine RGB transform. This is intentionally
/// narrower than arbitrary 3D LUT inversion: the inverse is accepted only
/// after Matrix3x3's condition and identity-residual checks succeed.
public struct KnownAffine3DTransform: Sendable {
    public let matrix: Matrix3x3
    public let offset: RGB64
    private let inverseMatrix: Matrix3x3

    public init(matrix: Matrix3x3, offset: RGB64, maxCondition: Double = 1e8) throws {
        guard maxCondition.isFinite, maxCondition > 0 else { throw Affine3DError.invalidTolerance }
        self.matrix = matrix
        self.offset = offset
        inverseMatrix = try matrix.inverted(maxCondition: maxCondition)
    }

    public func applying(to input: RGB64) throws -> RGB64 {
        let linear = try matrix.applying(to: input)
        return try RGB64(linear.r + offset.r, linear.g + offset.g, linear.b + offset.b)
    }

    public func inverse(_ output: RGB64,
                        inputDomain: LUTDomain? = nil,
                        outputDomain: LUTDomain? = nil,
                        tolerance: Double = 2e-12) throws -> RGB64 {
        guard tolerance.isFinite, tolerance >= 0 else { throw Affine3DError.invalidTolerance }
        guard output.r.isFinite, output.g.isFinite, output.b.isFinite else {
            throw Affine3DError.nonFinite
        }
        if let outputDomain, !contains(output, in: outputDomain) {
            throw Affine3DError.outsideDomain
        }
        let shifted = try RGB64(output.r - offset.r, output.g - offset.g, output.b - offset.b)
        let candidate = try inverseMatrix.applying(to: shifted)
        if let inputDomain, !contains(candidate, in: inputDomain) {
            throw Affine3DError.outsideDomain
        }
        let reconstructed = try applying(to: candidate)
        let residual = max(abs(reconstructed.r - output.r),
                           abs(reconstructed.g - output.g),
                           abs(reconstructed.b - output.b))
        guard residual.isFinite else { throw Affine3DError.nonFinite }
        guard residual <= tolerance * max(1, abs(output.r), abs(output.g), abs(output.b)) else {
            throw Affine3DError.excessiveResidual
        }
        return candidate
    }

    private func contains(_ value: RGB64, in domain: LUTDomain) -> Bool {
        domain.min.r <= value.r && value.r <= domain.max.r
            && domain.min.g <= value.g && value.g <= domain.max.g
            && domain.min.b <= value.b && value.b <= domain.max.b
    }
}

/// A caller-supplied, explicitly bounded inverse plan for an affine 3D
/// transform. The model is never inferred from LUT samples. Keeping the
/// domains and content fingerprint with the plan prevents a generation task
/// or durable batch checkpoint from silently changing its inverse semantics.
public struct KnownAffine3DInversePlan: Sendable {
    public let transform: KnownAffine3DTransform
    public let inputDomain: LUTDomain
    public let outputDomain: LUTDomain
    public let contentFingerprint: String

    public init(transform: KnownAffine3DTransform,
                inputDomain: LUTDomain,
                outputDomain: LUTDomain) {
        self.transform = transform
        self.inputDomain = inputDomain
        self.outputDomain = outputDomain
        var hasher = SHA256()
        hasher.update(data: Data("native.known-affine-3d-inverse.v1\0".utf8))
        func update(_ bits: UInt64) {
            var value = bits.littleEndian
            withUnsafeBytes(of: &value) { hasher.update(bufferPointer: $0) }
        }
        for value in transform.matrix.rowMajor {
            update(value.bitPattern)
        }
        for value in [transform.offset.r, transform.offset.g, transform.offset.b,
                      inputDomain.min.r, inputDomain.min.g, inputDomain.min.b,
                      inputDomain.max.r, inputDomain.max.g, inputDomain.max.b,
                      outputDomain.min.r, outputDomain.min.g, outputDomain.min.b,
                      outputDomain.max.r, outputDomain.max.g, outputDomain.max.b] {
            update(value.bitPattern)
        }
        self.contentFingerprint = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public func apply(_ output: RGB64, tolerance: Double = 2e-12) throws -> RGB64 {
        try transform.inverse(output, inputDomain: inputDomain,
                              outputDomain: outputDomain, tolerance: tolerance)
    }
}
