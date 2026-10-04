import Foundation

/// The explicit non-matrix bridge around CIELAB. Existing `TransformPlan`
/// remains an RGB plan; this type keeps XYZ/Lab channel semantics separate
/// until a persisted Lab project schema is approved.
public struct CIELABPlanSettings: Equatable, Codable, Sendable {
    public let sourceWhite: CIELABWhitePoint
    public let labWhite: CIELABWhitePoint
    public let destinationWhite: CIELABWhitePoint
    public let adaptation: ChromaticAdaptation

    public init(
        sourceWhite: CIELABWhitePoint,
        labWhite: CIELABWhitePoint,
        destinationWhite: CIELABWhitePoint,
        adaptation: ChromaticAdaptation
    ) {
        self.sourceWhite = sourceWhite
        self.labWhite = labWhite
        self.destinationWhite = destinationWhite
        self.adaptation = adaptation
    }
}

public enum CIELABStageID: String, Codable, Sendable {
    case xyzInput
    case labInput
    case xyzFromLab
    case whitePointAdaptation
    case labOutput
    case xyzOutput
}

public struct CIELABStageValue: Equatable, Sendable {
    public let id: CIELABStageID
    public let xyz: XYZ64?
    public let lab: CIELABColor?

    public init(id: CIELABStageID, xyz: XYZ64? = nil, lab: CIELABColor? = nil) {
        self.id = id
        self.xyz = xyz
        self.lab = lab
    }
}

public struct CIELABStageTrace: Equatable, Sendable {
    public let output: CIELABColor?
    public let xyzOutput: XYZ64?
    public let stages: [CIELABStageValue]

    public init(output: CIELABColor?, xyzOutput: XYZ64?, stages: [CIELABStageValue]) {
        self.output = output
        self.xyzOutput = xyzOutput
        self.stages = stages
    }
}

public enum CIELABPlanError: Error, Equatable, Sendable {
    case numeric(stage: CIELABStageID)

    public var stage: CIELABStageID {
        switch self {
        case let .numeric(stage): stage
        }
    }
}

/// A deterministic XYZ↔CIELAB plan with explicit white-point adaptation.
///
/// `xyzToLab` accepts XYZ normalized to `sourceWhite`, adapts to `labWhite`,
/// and encodes conventional Lab where L* is normalized to 0…1 and a*/b*
/// retain their conventional units. `labToXYZ` decodes from `labWhite`, then
/// adapts to `destinationWhite`. No RGB primaries or implicit display mapping
/// are involved.
public struct CIELABTransformPlan: Sendable {
    public let settings: CIELABPlanSettings
    private let sourceToLab: Matrix3x3
    private let labToDestination: Matrix3x3

    public init(settings: CIELABPlanSettings) throws {
        self.settings = settings
        sourceToLab = try Self.adaptationMatrix(
            from: settings.sourceWhite, to: settings.labWhite, using: settings.adaptation
        )
        labToDestination = try Self.adaptationMatrix(
            from: settings.labWhite, to: settings.destinationWhite, using: settings.adaptation
        )
    }

    public func xyzToLab(_ xyz: XYZ64) throws -> CIELABColor {
        try traceXYZToLab(xyz).output!
    }

    public func labToXYZ(_ lab: CIELABColor) throws -> XYZ64 {
        try traceLabToXYZ(lab).xyzOutput!
    }

    public func traceXYZToLab(_ xyz: XYZ64) throws -> CIELABStageTrace {
        let adapted: XYZ64
        do {
            adapted = try sourceToLab.applying(to: xyz)
        } catch {
            throw CIELABPlanError.numeric(stage: .whitePointAdaptation)
        }
        let lab: CIELABColor
        do {
            lab = try CIELABColorSpace.fromXYZ(adapted, white: settings.labWhite)
        } catch {
            throw CIELABPlanError.numeric(stage: .labOutput)
        }
        return CIELABStageTrace(
            output: lab,
            xyzOutput: nil,
            stages: [
                CIELABStageValue(id: .xyzInput, xyz: xyz),
                CIELABStageValue(id: .whitePointAdaptation, xyz: adapted),
                CIELABStageValue(id: .labOutput, lab: lab),
            ]
        )
    }

    public func traceLabToXYZ(_ lab: CIELABColor) throws -> CIELABStageTrace {
        let decoded: XYZ64
        do {
            decoded = try lab.toXYZ(white: settings.labWhite)
        } catch {
            throw CIELABPlanError.numeric(stage: .xyzFromLab)
        }
        let adapted: XYZ64
        do {
            adapted = try labToDestination.applying(to: decoded)
        } catch {
            throw CIELABPlanError.numeric(stage: .whitePointAdaptation)
        }
        return CIELABStageTrace(
            output: nil,
            xyzOutput: adapted,
            stages: [
                CIELABStageValue(id: .labInput, lab: lab),
                CIELABStageValue(id: .xyzFromLab, xyz: decoded),
                CIELABStageValue(id: .whitePointAdaptation, xyz: adapted),
                CIELABStageValue(id: .xyzOutput, xyz: adapted),
            ]
        )
    }

    private static func adaptationMatrix(
        from source: CIELABWhitePoint,
        to destination: CIELABWhitePoint,
        using adaptation: ChromaticAdaptation
    ) throws -> Matrix3x3 {
        let sourceXYZ = source.xyz
        let destinationXYZ = destination.xyz
        let sourceSum = sourceXYZ.x + sourceXYZ.y + sourceXYZ.z
        let destinationSum = destinationXYZ.x + destinationXYZ.y + destinationXYZ.z
        guard sourceSum.isFinite, destinationSum.isFinite, sourceSum > 0, destinationSum > 0 else {
            throw MatrixError.invalidChromaticity
        }
        let sourceChromaticity = try Chromaticity(
            x: sourceXYZ.x / sourceSum, y: sourceXYZ.y / sourceSum
        )
        let destinationChromaticity = try Chromaticity(
            x: destinationXYZ.x / destinationSum, y: destinationXYZ.y / destinationSum
        )
        return try adaptation.matrix(from: sourceChromaticity, to: destinationChromaticity)
    }
}

private extension Matrix3x3 {
    func applying(to xyz: XYZ64) throws -> XYZ64 {
        let rgb = try applying(to: RGB64(xyz.x, xyz.y, xyz.z))
        return try XYZ64(rgb.r, rgb.g, rgb.b)
    }
}
