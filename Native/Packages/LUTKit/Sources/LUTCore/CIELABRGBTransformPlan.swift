import Foundation

/// Explicit RGB↔XYZ↔CIELAB bridge. This is intentionally separate from the
/// existing RGB `TransformPlan`; Lab is not an RGB primary set or transfer ID.
public struct CIELABRGBPlanSettings: Equatable, Sendable {
    public let sourcePrimaries: ColorPrimaries
    public let sourceWhite: CIELABWhitePoint
    public let labWhite: CIELABWhitePoint
    public let destinationPrimaries: ColorPrimaries
    public let destinationWhite: CIELABWhitePoint
    public let adaptation: ChromaticAdaptation

    public init(
        sourcePrimaries: ColorPrimaries,
        sourceWhite: CIELABWhitePoint,
        labWhite: CIELABWhitePoint,
        destinationPrimaries: ColorPrimaries,
        destinationWhite: CIELABWhitePoint,
        adaptation: ChromaticAdaptation
    ) {
        self.sourcePrimaries = sourcePrimaries
        self.sourceWhite = sourceWhite
        self.labWhite = labWhite
        self.destinationPrimaries = destinationPrimaries
        self.destinationWhite = destinationWhite
        self.adaptation = adaptation
    }
}

public enum CIELABRGBStageID: String, Codable, Sendable {
    case rgbInput
    case labInput
    case xyzFromLab
    case xyzMatrix
    case whitePointAdaptation
    case labOutput
    case xyzOutput
    case rgbMatrix
    case rgbOutput
}

public struct CIELABRGBStageValue: Equatable, Sendable {
    public let id: CIELABRGBStageID
    public let rgb: RGB64?
    public let xyz: XYZ64?
    public let lab: CIELABColor?

    public init(
        id: CIELABRGBStageID,
        rgb: RGB64? = nil,
        xyz: XYZ64? = nil,
        lab: CIELABColor? = nil
    ) {
        self.id = id
        self.rgb = rgb
        self.xyz = xyz
        self.lab = lab
    }
}

public struct CIELABRGBStageTrace: Equatable, Sendable {
    public let rgbOutput: RGB64?
    public let labOutput: CIELABColor?
    public let stages: [CIELABRGBStageValue]

    public init(
        rgbOutput: RGB64?,
        labOutput: CIELABColor?,
        stages: [CIELABRGBStageValue]
    ) {
        self.rgbOutput = rgbOutput
        self.labOutput = labOutput
        self.stages = stages
    }
}

public enum CIELABRGBPlanError: Error, Equatable, Sendable {
    case sourceMatrix
    case destinationMatrix
    case sourceWhiteMismatch
    case destinationWhiteMismatch
    case lab(stage: CIELABStageID)
    case numeric(stage: CIELABRGBStageID)
}

public struct CIELABRGBTransformPlan: Sendable {
    public let settings: CIELABRGBPlanSettings
    private let sourceRGBToXYZ: Matrix3x3
    private let destinationXYZToRGB: Matrix3x3
    private let labPlan: CIELABTransformPlan

    public init(settings: CIELABRGBPlanSettings) throws {
        self.settings = settings
        guard Self.matches(settings.sourcePrimaries.white, settings.sourceWhite) else {
            throw CIELABRGBPlanError.sourceWhiteMismatch
        }
        guard Self.matches(settings.destinationPrimaries.white, settings.destinationWhite) else {
            throw CIELABRGBPlanError.destinationWhiteMismatch
        }
        do {
            sourceRGBToXYZ = try settings.sourcePrimaries.rgbToXYZ()
        } catch {
            throw CIELABRGBPlanError.sourceMatrix
        }
        do {
            destinationXYZToRGB = try settings.destinationPrimaries.rgbToXYZ().inverted()
        } catch {
            throw CIELABRGBPlanError.destinationMatrix
        }
        labPlan = try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: settings.sourceWhite,
            labWhite: settings.labWhite,
            destinationWhite: settings.destinationWhite,
            adaptation: settings.adaptation
        ))
    }

    private static func matches(_ chromaticity: Chromaticity, _ white: CIELABWhitePoint) -> Bool {
        let xyz = white.xyz
        let sum = xyz.x + xyz.y + xyz.z
        guard sum.isFinite, sum > 0 else { return false }
        let x = xyz.x / sum
        let y = xyz.y / sum
        return abs(chromaticity.x - x) <= 2e-4 && abs(chromaticity.y - y) <= 2e-4
    }

    public func rgbToLab(_ rgb: RGB64) throws -> CIELABColor {
        try traceRGBToLab(rgb).labOutput!
    }

    public func labToRGB(_ lab: CIELABColor) throws -> RGB64 {
        try traceLabToRGB(lab).rgbOutput!
    }

    public func traceRGBToLab(_ rgb: RGB64) throws -> CIELABRGBStageTrace {
        let xyzRGB: RGB64
        do {
            xyzRGB = try sourceRGBToXYZ.applying(to: rgb)
        } catch {
            throw CIELABRGBPlanError.numeric(stage: .xyzMatrix)
        }
        let xyz: XYZ64
        do {
            xyz = try XYZ64(xyzRGB.r, xyzRGB.g, xyzRGB.b)
        } catch {
            throw CIELABRGBPlanError.numeric(stage: .xyzMatrix)
        }
        let labTrace: CIELABStageTrace
        do {
            labTrace = try labPlan.traceXYZToLab(xyz)
        } catch let error as CIELABPlanError {
            throw CIELABRGBPlanError.lab(stage: error.stage)
        } catch {
            throw CIELABRGBPlanError.lab(stage: .labOutput)
        }
        guard let lab = labTrace.output else {
            throw CIELABRGBPlanError.numeric(stage: .labOutput)
        }
        let adapted = labTrace.stages.first { $0.id == .whitePointAdaptation }?.xyz
        return CIELABRGBStageTrace(
            rgbOutput: nil,
            labOutput: lab,
            stages: [
                CIELABRGBStageValue(id: .rgbInput, rgb: rgb),
                CIELABRGBStageValue(id: .xyzMatrix, xyz: xyz),
                CIELABRGBStageValue(id: .whitePointAdaptation, xyz: adapted),
                CIELABRGBStageValue(id: .labOutput, lab: lab),
            ]
        )
    }

    public func traceLabToRGB(_ lab: CIELABColor) throws -> CIELABRGBStageTrace {
        let labTrace: CIELABStageTrace
        do {
            labTrace = try labPlan.traceLabToXYZ(lab)
        } catch let error as CIELABPlanError {
            throw CIELABRGBPlanError.lab(stage: error.stage)
        } catch {
            throw CIELABRGBPlanError.lab(stage: .xyzOutput)
        }
        guard let adapted = labTrace.xyzOutput else {
            throw CIELABRGBPlanError.numeric(stage: .whitePointAdaptation)
        }
        let destinationXYZ = try RGB64(adapted.x, adapted.y, adapted.z)
        let rgb: RGB64
        do {
            rgb = try destinationXYZToRGB.applying(to: destinationXYZ)
        } catch {
            throw CIELABRGBPlanError.numeric(stage: .rgbMatrix)
        }
        return CIELABRGBStageTrace(
            rgbOutput: rgb,
            labOutput: nil,
            stages: [
                CIELABRGBStageValue(id: .labInput, lab: lab),
                CIELABRGBStageValue(id: .xyzFromLab, xyz: labTrace.stages.first { $0.id == .xyzFromLab }?.xyz),
                CIELABRGBStageValue(id: .whitePointAdaptation, xyz: adapted),
                CIELABRGBStageValue(id: .rgbMatrix, rgb: rgb),
                CIELABRGBStageValue(id: .rgbOutput, rgb: rgb),
            ]
        )
    }
}
