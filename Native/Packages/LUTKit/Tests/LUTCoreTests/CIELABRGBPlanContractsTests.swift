import XCTest
@testable import LUTCore

final class CIELABRGBPlanContractsTests: XCTestCase {
    func testRGBToLabKeepsMatrixAndLabStagesExplicit() throws {
        let plan = try CIELABRGBTransformPlan(settings: CIELABRGBPlanSettings(
            sourcePrimaries: .srgb,
            sourceWhite: .d65,
            labWhite: .d50,
            destinationPrimaries: .srgb,
            destinationWhite: .d65,
            adaptation: .bradford
        ))
        let trace = try plan.traceRGBToLab(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(trace.stages.map(\.id), [.rgbInput, .xyzMatrix, .whitePointAdaptation, .labOutput])
        XCTAssertNotNil(trace.stages[0].rgb)
        XCTAssertNotNil(trace.stages[1].xyz)
        XCTAssertNotNil(trace.stages[2].xyz)
        XCTAssertNotNil(trace.stages[3].lab)
    }

    func testSRGBD65ToD50LabMatchesIndependentReference() throws {
        let settings = CIELABRGBPlanSettings(
            sourcePrimaries: .srgb,
            sourceWhite: .d65,
            labWhite: .d50,
            destinationPrimaries: .srgb,
            destinationWhite: .d65,
            adaptation: .bradford
        )
        let plan = try CIELABRGBTransformPlan(settings: settings)
        let actual = try plan.rgbToLab(try RGB64(0.25, 0.5, 0.75))
        // Independent published-primary/Bradford calculation, frozen as Double values.
        XCTAssertEqual(actual.lStar, 0.7351559484043333, accuracy: 2e-14)
        XCTAssertEqual(actual.aStar, -0.10203582393322475, accuracy: 2e-14)
        XCTAssertEqual(actual.bStar, -0.24276801877406728, accuracy: 2e-14)
    }

    func testRGBLabRGBRoundTrip33And65Grid() throws {
        let plan = try CIELABRGBTransformPlan(settings: CIELABRGBPlanSettings(
            sourcePrimaries: .srgb,
            sourceWhite: .d65,
            labWhite: .d50,
            destinationPrimaries: .srgb,
            destinationWhite: .d65,
            adaptation: .bradford
        ))
        var maximum = 0.0
        var checkedReverseStages = false
        for size in [33, 65] {
            for r in 0..<size {
                for g in 0..<size {
                    for b in 0..<size {
                        let input = try RGB64(
                            Double(r) / Double(size - 1),
                            Double(g) / Double(size - 1),
                            Double(b) / Double(size - 1)
                        )
                        let lab = try plan.rgbToLab(input)
                        let reverseTrace = try plan.traceLabToRGB(lab)
                        if !checkedReverseStages {
                            XCTAssertEqual(
                                reverseTrace.stages.map(\.id),
                                [.labInput, .xyzFromLab, .whitePointAdaptation, .rgbMatrix, .rgbOutput]
                            )
                            checkedReverseStages = true
                        }
                        let restored = try plan.labToRGB(lab)
                        maximum = max(
                            maximum,
                            abs(restored.r - input.r),
                            abs(restored.g - input.g),
                            abs(restored.b - input.b)
                        )
                    }
                }
            }
        }
        XCTAssertLessThan(maximum, 2e-12)
    }

    func testNonFiniteRGBIsRejectedBeforeMatrixStage() throws {
        let plan = try CIELABRGBTransformPlan(settings: CIELABRGBPlanSettings(
            sourcePrimaries: .srgb,
            sourceWhite: .d65,
            labWhite: .d50,
            destinationPrimaries: .srgb,
            destinationWhite: .d65,
            adaptation: .bradford
        ))
        XCTAssertThrowsError(try plan.rgbToLab(RGB64(.nan, 0, 0)))
    }

    func testDeclaredWhitePointMustMatchRGBPrimaries() {
        XCTAssertThrowsError(try CIELABRGBTransformPlan(settings: CIELABRGBPlanSettings(
            sourcePrimaries: .srgb,
            sourceWhite: .d50,
            labWhite: .d50,
            destinationPrimaries: .srgb,
            destinationWhite: .d65,
            adaptation: .bradford
        ))) { error in
            XCTAssertEqual(error as? CIELABRGBPlanError, .sourceWhiteMismatch)
        }
    }
}
