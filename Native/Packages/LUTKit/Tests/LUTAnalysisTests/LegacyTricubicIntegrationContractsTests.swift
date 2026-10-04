import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class LegacyTricubicIntegrationContractsTests: XCTestCase {
    func testPreparedCubeSamplingAndGrayAxisUseTheSelectedKernel() throws {
        var samples: [RGB64] = []
        for b in 0..<4 { for g in 0..<4 { for r in 0..<4 {
            let x = Double(r) / 3, y = Double(g) / 3, z = Double(b) / 3
            samples.append(try RGB64([0, 1, 1, 0][r], y * y + x * z, z * z * z))
        } } }
        let lut = try CubeLUT(dimension: .three, size: 4, domain: .unit, samples: samples)
        let sampler = try lut.preparedSampler(interpolation: .tricubicLegacyV1)
        let p = try RGB64(0.5, 0.5, 0.5)
        XCTAssertEqual(try sampler.sample(p, outside: .reject).r, 1.125, accuracy: 2e-12)
        XCTAssertEqual(try lut.sample(p, interpolation: .tricubicLegacyV1, outside: .reject),
                       try sampler.sample(p, outside: .reject))
        let report = try GrayAxisAnalyzer.extract(lut, interpolation: .tricubicLegacyV1)
        XCTAssertEqual(report.interpolation, .tricubicLegacyV1)
        XCTAssertEqual(report.samples.count, 4)
        XCTAssertEqual(report.midpointProbeCount, 3)
        XCTAssertGreaterThan(report.maximumMidpointResidual, 0.1)
        let volume = try LUTVolume3D(size: 4, domain: .unit, samples: samples)
        let volumeReport = try GrayAxisAnalyzer.extract(volume, interpolation: .tricubicLegacyV1)
        XCTAssertEqual(volumeReport.maximumMidpointResidual, report.maximumMidpointResidual)
    }

    func testInsufficientOneDimensionalAndShaperStencilsAreRejected() throws {
        let zero = try RGB64(0, 0, 0), one = try RGB64(1, 1, 1)
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit, samples: [zero, one])
        XCTAssertThrowsError(try lut.preparedSampler(interpolation: .tricubicLegacyV1))
        XCTAssertThrowsError(try lut.sample(zero, interpolation: .tricubicLegacyV1, outside: .reject))
        let shaper = try CubeShaper(size: 2, domain: .unit, samples: [zero, one])
        let combined = try CubeLUT(dimension: .three, size: 4, domain: .unit,
            samples: Array(repeating: zero, count: 64), shaper: shaper)
        XCTAssertThrowsError(try combined.preparedSampler(interpolation: .tricubicLegacyV1))
    }

    func testPreparedCubicCombinedAllocationBudgetIsCheckedBeforePreparation() throws {
        let zero = try RGB64(0,0,0)
        let values = Array(repeating: zero, count: LegacyCubicCurve1D.maximumSampleCount / 3 + 1)
        let lut = try CubeLUT(dimension: .one, size: values.count, domain: .unit, samples: values)
        XCTAssertThrowsError(try lut.preparedSampler(interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? CubeSamplingError, .resourceLimit)
        }
        let shaper = try CubeShaper(size: values.count, domain: .unit, samples: values)
        let combined = try CubeLUT(dimension: .three, size: 4, domain: .unit,
                                  samples: Array(repeating: zero, count: 64), shaper: shaper)
        XCTAssertThrowsError(try combined.preparedSampler(interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? CubeSamplingError, .resourceLimit)
        }
    }

    func testOneDimensionalCubicUsesIndividualDomainsAndReportsSlopes() throws {
        let domain = try LUTDomain(min: RGB64(-2, 1, -3), max: RGB64(2, 5, 1))
        let samples = try [0.0, 0.5, 1].map { try RGB64($0*$0, 1-$0, 2*$0) }
        let lut = try CubeLUT(dimension: .one, size: 3, domain: domain, samples: samples)
        let sampler = try lut.preparedSampler(interpolation: .tricubicLegacyV1)
        let p = try RGB64(-1, 2, -2)
        let result = try sampler.sample(p, outside: .reject)
        XCTAssertEqual(result.r, 0.06296875, accuracy: 2e-12)
        XCTAssertEqual(result.g, 0.75, accuracy: 2e-12)
        XCTAssertEqual(result.b, 0.5, accuracy: 2e-12)
        XCTAssertEqual(sampler.cubicEndpointSlopes.count, 3)
        XCTAssertTrue(sampler.cubicEndpointSlopes[0].lower.modified)
        XCTAssertEqual(try lut.sample(p, interpolation: .tricubicLegacyV1, outside: .reject), result)
        let outside = try sampler.sample(RGB64(-3, 6, 2), outside: .legacyExtensionV1)
        XCTAssertEqual(outside.r, -0.001875, accuracy: 2e-12)
        XCTAssertEqual(outside.g, -0.25, accuracy: 2e-12)
        XCTAssertEqual(outside.b, 2.5, accuracy: 2e-12)
        XCTAssertThrowsError(try GrayAxisAnalyzer.extract(lut, interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? GrayAxisError, .requiresThreeDimensionalLUT)
        }
    }

    func testCombinedShaperMatchesFrozenLegacyOrder() throws {
        struct Reference: Decodable {
            let combined: Combined
            struct Combined: Decodable {
                let size: Int, lower: Double, upper: Double, shaper: [Double], samples: [[Double]], probes: [Probe]
            }
            struct Probe: Decodable { let input: [Double], output: [Double] }
        }
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/cubic1d-legacy-reference.json"))).combined
        let domain = try LUTDomain(min: RGB64(reference.lower, reference.lower, reference.lower),
                                   max: RGB64(reference.upper, reference.upper, reference.upper))
        let shaper = try CubeShaper(size: reference.shaper.count, domain: domain,
            samples: reference.shaper.map { try RGB64($0,$0,$0) })
        let lut = try CubeLUT(dimension: .three, size: reference.size, domain: .unit,
            samples: reference.samples.map { try RGB64($0[0],$0[1],$0[2]) }, shaper: shaper)
        let sampler = try lut.preparedSampler(interpolation: .tricubicLegacyV1)
        XCTAssertEqual(sampler.cubicEndpointSlopes.count, 3)
        var maximum = 0.0
        for probe in reference.probes {
            let output = try sampler.sample(RGB64(probe.input[0],probe.input[1],probe.input[2]), outside: .reject)
            for c in 0..<3 {
                let error = abs(output[c]-probe.output[c]) / max(1,abs(probe.output[c]))
                maximum = max(maximum,error)
                XCTAssertLessThanOrEqual(error, 2e-12)
            }
        }
        print("旧组合 shaper 冻结参照：\(reference.probes.count) 点，最大尺度化误差 \(maximum)")
    }

    func testUnequalShaperAndVolumeDomainsAndUnsupportedExtension() throws {
        let shaperDomain = try LUTDomain(min: RGB64(-2, 1, -3), max: RGB64(2, 5, 1))
        let volumeDomain = try LUTDomain(min: RGB64(2, 4, 6), max: RGB64(4, 8, 10))
        let shaper = try CubeShaper(size: 3, domain: shaperDomain,
            samples: [RGB64(2,4,6),RGB64(3,6,8),RGB64(4,8,10)])
        let grid = try Grid3D(size: 4, domain: volumeDomain)
        let samples = try (0..<grid.nodeCount).map { try grid.coordinate(at: $0) }
        let lut = try CubeLUT(dimension: .three, size: 4, domain: volumeDomain, samples: samples, shaper: shaper)
        let sampler = try lut.preparedSampler(interpolation: .tricubicLegacyV1)
        let result = try sampler.sample(RGB64(-1,2,-2), outside: .reject)
        for c in 0..<3 { XCTAssertEqual(result[c], [2.5,5,7][c], accuracy: 2e-12) }
        XCTAssertThrowsError(try sampler.sample(RGB64(-3,2,-2), outside: .reject))
        let clamped = try sampler.sample(RGB64(-3,2,-2), outside: .clampToDomain)
        XCTAssertEqual(clamped.r, 2, accuracy: 2e-12)
        let input = try RGB64(3,6,8)
        let volume = try LUTVolume3D(size: 4, domain: volumeDomain, samples: samples)
        for interpolation in [LUTInterpolation.trilinear, .tetrahedral, .tricubicLegacyV1] {
            XCTAssertThrowsError(try volume.sample(input, interpolation: interpolation, outside: .legacyExtensionV1)) {
                XCTAssertEqual($0 as? VolumeError, .unsupportedOutsidePolicy)
            }
        }
        XCTAssertThrowsError(try sampler.sample(RGB64(0,3,-1), outside: .legacyExtensionV1)) {
            XCTAssertEqual($0 as? VolumeError, .unsupportedOutsidePolicy)
        }
        let one = try CubeLUT(dimension: .one, size: 3, domain: shaperDomain, samples: shaper.samples)
        XCTAssertThrowsError(try one.sample(RGB64(0,3,-1), interpolation: .trilinear, outside: .legacyExtensionV1)) {
            XCTAssertEqual($0 as? VolumeError, .unsupportedOutsidePolicy)
        }
    }

    func testShaperOvershootReachesTheExplicitVolumeOutsidePolicy() throws {
        let shaper = try CubeShaper(size: 4, domain: .unit,
            samples: [0.0,1,1,0].map { try RGB64($0,$0,$0) })
        let grid = try Grid3D(size: 4, domain: .unit)
        let identity = try (0..<grid.nodeCount).map { try grid.coordinate(at: $0) }
        let lut = try CubeLUT(dimension: .three, size: 4, domain: .unit, samples: identity, shaper: shaper)
        let sampler = try lut.preparedSampler(interpolation: .tricubicLegacyV1)
        let input = try RGB64(0.5,0.5,0.5)
        XCTAssertThrowsError(try sampler.sample(input, outside: .reject)) {
            XCTAssertEqual($0 as? VolumeError, .outsideDomain)
        }
        XCTAssertEqual(try sampler.sample(input, outside: .clampToDomain), try RGB64(1,1,1))
        XCTAssertEqual(lut.shaper?.samples, shaper.samples)
    }
}
