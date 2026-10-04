import XCTest
@testable import LUTCore

final class CIELABPlanContractsTests: XCTestCase {
    func testXYZToLabUsesExplicitWhitePointAdaptationStage() throws {
        let settings = CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d50,
            destinationWhite: .d50,
            adaptation: .bradford
        )
        let plan = try CIELABTransformPlan(settings: settings)
        let trace = try plan.traceXYZToLab(CIELABWhitePoint.d65.xyz)
        let output = try XCTUnwrap(trace.output)

        XCTAssertEqual(trace.stages.map(\.id), [.xyzInput, .whitePointAdaptation, .labOutput])
        XCTAssertEqual(output.lStar, 1.0, accuracy: 2e-12)
        XCTAssertEqual(output.aStar, 0.0, accuracy: 2e-12)
        XCTAssertEqual(output.bStar, 0.0, accuracy: 2e-12)
    }

    func testLabToXYZUsesDestinationWhiteAndRoundTrips() throws {
        let plan = try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d50,
            destinationWhite: .d65,
            adaptation: .cieCAT02
        ))
        let source = try XYZ64(0.25, 0.4, 0.1)
        let lab = try plan.xyzToLab(source)
        let restored = try plan.labToXYZ(lab)
        XCTAssertEqual(restored.x, source.x, accuracy: 4e-12)
        XCTAssertEqual(restored.y, source.y, accuracy: 4e-12)
        XCTAssertEqual(restored.z, source.z, accuracy: 4e-12)
    }

    func testBradfordPlanMatchesIndependentNonNeutralReference() throws {
        let plan = try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d50,
            destinationWhite: .d50,
            adaptation: .bradford
        ))
        let actual = try plan.xyzToLab(try XYZ64(0.25, 0.4, 0.1))
        // Independent Bradford matrix multiplication and CIE piecewise reference.
        XCTAssertEqual(actual.lStar, 0.6960295121241488, accuracy: 2e-14)
        XCTAssertEqual(actual.aStar, -0.43451429737349556, accuracy: 2e-14)
        XCTAssertEqual(actual.bStar, 0.5612913450770792, accuracy: 2e-14)
    }

    func testTraceSeparatesLabAndXYZChannelsAndRejectsNonFinite() throws {
        let plan = try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d65,
            destinationWhite: .d65,
            adaptation: .bradford
        ))
        let trace = try plan.traceLabToXYZ(try CIELABColor(lStar: 0.5, aStar: 12, bStar: -8))
        XCTAssertEqual(trace.stages.map(\.id), [.labInput, .xyzFromLab, .whitePointAdaptation, .xyzOutput])
        XCTAssertNil(trace.stages[0].xyz)
        XCTAssertNotNil(trace.stages[0].lab)
        XCTAssertNotNil(trace.stages[1].xyz)
        XCTAssertNotNil(trace.stages[3].xyz)
        XCTAssertThrowsError(try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d50,
            destinationWhite: .d65,
            adaptation: .bradford
        )).xyzToLab(try XYZ64(.infinity, 0, 0)))
    }

    func testExplicitWhitePointPlanRoundTrips33And65Grids() throws {
        let plan = try CIELABTransformPlan(settings: CIELABPlanSettings(
            sourceWhite: .d65,
            labWhite: .d50,
            destinationWhite: .d65,
            adaptation: .bradford
        ))
        var maximum = 0.0
        for size in [33, 65] {
            for r in 0..<size {
                for g in 0..<size {
                    for b in 0..<size {
                        let source = try XYZ64(
                            Double(r) / Double(size - 1),
                            Double(g) / Double(size - 1),
                            Double(b) / Double(size - 1)
                        )
                        let restored = try plan.labToXYZ(try plan.xyzToLab(source))
                        maximum = max(
                            maximum,
                            abs(restored.x - source.x),
                            abs(restored.y - source.y),
                            abs(restored.z - source.z)
                        )
                    }
                }
            }
        }
        XCTAssertLessThan(maximum, 2e-12)
    }
}
