import Foundation
import XCTest
import LUTCore

final class LegacyCubicCurveContractsTests: XCTestCase {
    private struct Reference: Decodable {
        let cases: [Case]
        struct Case: Decodable {
            let values: [Double], lower: Double, upper: Double, slopes: [Double], probes: [Probe]
        }
        struct Probe: Decodable { let input: Double, output: Double }
    }
    func testFrozenLegacyCurvesAndEndpointExtension() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/cubic1d-legacy-reference.json")))
        var maximum = 0.0, count = 0
        for item in reference.cases {
            let curve = try LegacyCubicCurve1D(values: item.values, lower: item.lower, upper: item.upper)
            XCTAssertEqual(curve.values, item.values)
            XCTAssertEqual(curve.endpointSlopes.lower.applied, item.slopes[0])
            XCTAssertEqual(curve.endpointSlopes.upper.applied, item.slopes[1])
            for probe in item.probes {
                let actual = try curve.sample(probe.input, outside: .legacyExtensionV1)
                let error = abs(actual - probe.output) / max(1, abs(probe.output))
                maximum = max(maximum, error); count += 1
                XCTAssertLessThanOrEqual(error, 2e-12)
            }
        }
        print("旧 1D cubic 冻结参照：\(count) 点，最大尺度化误差 \(maximum)")
    }
    func testIndependentPolynomialOvershootAndSlopeReport() throws {
        let quadratic = try LegacyCubicCurve1D(values: [0, 0.25, 1], lower: -2, upper: 2)
        // Legacy changes a zero endpoint slope; the interior is consequently not x².
        XCTAssertEqual(quadratic.endpointSlopes.lower.raw, 0)
        XCTAssertEqual(quadratic.endpointSlopes.lower.applied, 0.00375)
        XCTAssertTrue(quadratic.endpointSlopes.lower.modified)
        XCTAssertFalse(quadratic.endpointSlopes.upper.modified)
        XCTAssertEqual(try quadratic.sample(-1, outside: .reject), 0.06296875, accuracy: 2e-12)
        let linear = try LegacyCubicCurve1D(values: [3, 1, -1], lower: -2, upper: 2)
        for x in [-3.0, -2, -0.71, 0, 1.3, 2, 4] {
            XCTAssertEqual(try linear.sample(x, outside: .legacyExtensionV1), 1-x, accuracy: 2e-12)
        }
        let hump = try LegacyCubicCurve1D(values: [0, 1, 1, 0], lower: 0, upper: 1)
        XCTAssertEqual(try hump.sample(0.5, outside: .reject), 1.125, accuracy: 2e-12)
        XCTAssertEqual(hump.values, [0,1,1,0])
        let flat = try LegacyCubicCurve1D(values: [0.375,0.375,0.375], lower: 0, upper: 1)
        XCTAssertTrue(flat.endpointSlopes.lower.modified)
        XCTAssertTrue(flat.endpointSlopes.upper.modified)
        XCTAssertEqual(try flat.sample(0.25, outside: .reject), 0.37546875, accuracy: 2e-12)
    }
    func testExplicitOutsidePoliciesAndInvalidInputs() throws {
        let curve = try LegacyCubicCurve1D(values: [0,0.5,1], lower: 0, upper: 1)
        XCTAssertThrowsError(try curve.sample(-0.1, outside: .reject))
        XCTAssertEqual(try curve.sample(-0.1, outside: .clampToDomain), 0)
        XCTAssertEqual(try curve.sample(-0.1, outside: .legacyExtensionV1), -0.1, accuracy: 2e-12)
        XCTAssertThrowsError(try curve.sample(.nan, outside: .clampToDomain))
        XCTAssertThrowsError(try LegacyCubicCurve1D(values: [0,1], lower: 0, upper: 1))
        XCTAssertThrowsError(try LegacyCubicCurve1D(values: [0,.infinity,1], lower: 0, upper: 1))
        XCTAssertThrowsError(try LegacyCubicCurve1D(values: [0,0.5,1], lower: 1, upper: 0))
        XCTAssertThrowsError(try LegacyCubicCurve1D(values: [0,0.5,1], lower: -.greatestFiniteMagnitude,
                                                  upper: .greatestFiniteMagnitude))
        XCTAssertThrowsError(try LegacyCubicCurve1D(values: Array(repeating: 0,
            count: LegacyCubicCurve1D.maximumSampleCount + 1), lower: 0, upper: 1))
    }

}
