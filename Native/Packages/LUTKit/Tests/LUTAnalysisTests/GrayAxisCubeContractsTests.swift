import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis

final class GrayAxisCubeContractsTests: XCTestCase {
    func testShaperInputDomainAndThreeDCrossTermResidual() throws {
        let sourceDomain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let shaper = try CubeShaper(size: 2, domain: sourceDomain, samples: [
            RGB64(0.25, 0.25, 0.25), RGB64(0.75, 0.75, 0.75)
        ])
        let samples = try (0..<2).flatMap { b in
            try (0..<2).flatMap { g in
                try (0..<2).map { r in
                    try RGB64(Double(r * g), Double(g * b), Double(b * r))
                }
            }
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                              samples: samples, shaper: shaper)
        let report = try GrayAxisAnalyzer.extract(lut, interpolation: .trilinear)
        XCTAssertEqual(report.samples.count, 2)
        XCTAssertEqual(report.samples[0].input, sourceDomain.min)
        XCTAssertEqual(report.samples[1].input, sourceDomain.max)
        XCTAssertEqual(report.samples[0].output, try RGB64(0.0625, 0.0625, 0.0625))
        XCTAssertEqual(report.samples[1].output, try RGB64(0.5625, 0.5625, 0.5625))
        XCTAssertEqual(report.maximumMidpointResidual, 0.0625, accuracy: 1e-12)
    }

    func testOneDimensionalLUTCannotMasqueradeAsThreeDGrayAxis() throws {
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        XCTAssertThrowsError(try GrayAxisAnalyzer.extract(lut, interpolation: .tetrahedral)) {
            XCTAssertEqual($0 as? GrayAxisError, .requiresThreeDimensionalLUT)
        }
    }

    func testAffineIdentityGrayAxisHasZeroMidpointResidual() throws {
        let size = 3
        var samples: [RGB64] = []
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let point = Double(r) / Double(size - 1)
                    let green = Double(g) / Double(size - 1)
                    let blue = Double(b) / Double(size - 1)
                    samples.append(try RGB64(point, green, blue))
                }
            }
        }
        let volume = try LUTVolume3D(size: size, domain: .unit, samples: samples)

        for interpolation in [LUTInterpolation.trilinear, .tetrahedral] {
            let report = try GrayAxisAnalyzer.extract(volume, interpolation: interpolation)
            XCTAssertEqual(report.samples.map(\.output), report.samples.map(\.input))
            XCTAssertEqual(report.midpointProbeCount, size - 1)
            XCTAssertLessThanOrEqual(report.maximumMidpointResidual, 2e-15)
        }
    }
}
